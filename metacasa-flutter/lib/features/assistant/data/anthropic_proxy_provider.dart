import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_init.dart';

/// Provider de chat con Claude Haiku 4.5 vía la Edge Function `ai-proxy`.
///
/// Port del `AnthropicProvider` de iOS (`Core/AI/Providers/AnthropicProvider.swift`)
/// — versión **no-streaming** para v1, que es lo que `functions.invoke` soporta
/// limpio (el streaming SSE queda para una wave posterior con `http` crudo).
///
/// **Privacidad**: la API key de Anthropic NUNCA llega al cliente. El proxy
/// valida el JWT (lo adjunta `supabase_flutter` automáticamente) y forwardea con
/// el secret server-side. Rate limit server-side (50/día, 1000/mes por user).
///
/// El loop `tool_use → tool_result → continue` lo maneja el `AssistantController`
/// client-side: este provider sólo hace UNA llamada y parsea UN turno.
class AnthropicProxyProvider {
  const AnthropicProxyProvider();

  /// Modelo fijo (igual que iOS). El proxy igual lo overridea/valida.
  static const String model = 'claude-haiku-4-5-20251001';
  static const int maxTokens = 1024;
  static const double temperature = 0.7;

  /// Envía un turno al proxy y devuelve el [AiTurn] parseado.
  ///
  /// - [system]: system prompt completo (string). Se envuelve en el bloque
  ///   `[{type:text, text, cache_control:{type:ephemeral}}]` que espera el proxy
  ///   (espejo del `ProxyRequest.system` de iOS — habilita prompt caching).
  /// - [messages]: historial Anthropic (`[{role, content}]`) donde `content` es
  ///   un String (texto) o una lista de bloques (tool_use / tool_result).
  /// - [tools]: schemas de tools en formato Anthropic (`input_schema`).
  ///
  /// Lanza [AiException] (mensajes en español rioplatense) ante: sin sesión,
  /// rate limit (429), error HTTP (>=400) o respuesta inválida.
  Future<AiTurn> respond({
    required String system,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async {
    if (!supabaseReady) {
      throw const AiException(AiErrorKind.noSession);
    }
    final SupabaseClient client = supabase;
    if (client.auth.currentSession == null) {
      throw const AiException(AiErrorKind.noSession);
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'system': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'text',
          'text': system,
          'cache_control': <String, dynamic>{'type': 'ephemeral'},
        },
      ],
      'messages': messages,
      'tools': tools,
      'model': model,
      'max_tokens': maxTokens,
      'temperature': temperature,
    };

    final FunctionResponse res;
    try {
      res = await client.functions.invoke('ai-proxy', body: body);
    } on FunctionException catch (e) {
      // invoke() lanza esto en respuestas HTTP de error (>=400).
      if (e.status == 429) {
        throw AiException.rateLimit(_rateInfo(e.details));
      }
      throw AiException.api(e.status, _detailString(e.details));
    } catch (_) {
      throw const AiException(AiErrorKind.network);
    }

    if (res.status == 429) {
      throw AiException.rateLimit(_rateInfo(res.data));
    }
    if (res.status < 200 || res.status >= 300) {
      throw AiException.api(res.status, _detailString(res.data));
    }

    final dynamic data = res.data;
    if (data is! Map) {
      throw const AiException(AiErrorKind.invalidResponse);
    }
    return AiTurn.fromJson(Map<String, dynamic>.from(data));
  }

  /// Extrae `(daily, monthly)` del body del 429 (`daily_used`/`monthly_used`).
  ({int daily, int monthly}) _rateInfo(dynamic data) {
    if (data is Map) {
      final int d = (data['daily_used'] as num?)?.toInt() ?? 0;
      final int m = (data['monthly_used'] as num?)?.toInt() ?? 0;
      return (daily: d, monthly: m);
    }
    return (daily: 0, monthly: 0);
  }

  /// Stringifica el detalle de error para diagnóstico (no se muestra al user).
  String _detailString(dynamic data) {
    if (data == null) return '';
    if (data is Map) {
      final dynamic err = data['error'] ?? data['message'];
      if (err != null) return err.toString();
    }
    return data.toString();
  }
}

/// Un turno parseado de la respuesta de la Messages API de Anthropic.
///
/// Espejo de lo que en iOS es `APIResponse` (content blocks + stop_reason). El
/// controller usa [text] cuando el turno termina (`end_turn`) y [toolUses] +
/// [rawContent] cuando el modelo pide tools (`tool_use`).
class AiTurn {
  const AiTurn({
    required this.text,
    required this.toolUses,
    required this.stopReason,
    required this.rawContent,
  });

  /// Texto concatenado de todos los bloques `type:text` (separados por `\n`).
  final String text;

  /// Bloques `type:tool_use` que el modelo quiere ejecutar.
  final List<AiToolUse> toolUses;

  /// `stop_reason` de Anthropic: `end_turn`, `tool_use`, `max_tokens`, …
  final String stopReason;

  /// El array `content` crudo de Anthropic — se re-inyecta TAL CUAL como turno
  /// `assistant` en la próxima request del loop (Anthropic exige los mismos
  /// bloques tool_use para casar los tool_result).
  final List<Map<String, dynamic>> rawContent;

  /// `true` si el modelo pidió ejecutar al menos una tool.
  bool get wantsTools => stopReason == 'tool_use' || toolUses.isNotEmpty;

  factory AiTurn.fromJson(Map<String, dynamic> json) {
    final List<dynamic> content =
        (json['content'] as List<dynamic>?) ?? const <dynamic>[];
    final List<String> texts = <String>[];
    final List<AiToolUse> tools = <AiToolUse>[];
    final List<Map<String, dynamic>> raw = <Map<String, dynamic>>[];

    for (final dynamic block in content) {
      if (block is! Map) continue;
      final Map<String, dynamic> b = Map<String, dynamic>.from(block);
      raw.add(b);
      final String? type = b['type'] as String?;
      if (type == 'text') {
        final String? t = b['text'] as String?;
        if (t != null && t.isNotEmpty) texts.add(t);
      } else if (type == 'tool_use') {
        final String? id = b['id'] as String?;
        final String? name = b['name'] as String?;
        if (id != null && name != null) {
          tools.add(AiToolUse(
            id: id,
            name: name,
            input: b['input'] is Map
                ? Map<String, dynamic>.from(b['input'] as Map)
                : const <String, dynamic>{},
          ));
        }
      }
    }

    return AiTurn(
      text: texts.join('\n'),
      toolUses: tools,
      stopReason: (json['stop_reason'] as String?) ?? 'end_turn',
      rawContent: raw,
    );
  }
}

/// Un bloque `tool_use`: la tool que el modelo quiere correr + sus args.
class AiToolUse {
  const AiToolUse({
    required this.id,
    required this.name,
    required this.input,
  });

  final String id;
  final String name;
  final Map<String, dynamic> input;
}

/// Categoría de error del asistente cloud.
enum AiErrorKind {
  noSession,
  rateLimit,
  api,
  invalidResponse,
  network,
  toolLoop
}

/// Error tipado del asistente con mensaje amigable en español rioplatense.
/// Espejo de `AnthropicProvider.AnthropicError` de iOS.
class AiException implements Exception {
  const AiException(
    this.kind, {
    this.status = 0,
    this.detail = '',
    this.dailyUsed = 0,
    this.monthlyUsed = 0,
  });

  factory AiException.rateLimit(({int daily, int monthly}) info) => AiException(
        AiErrorKind.rateLimit,
        status: 429,
        dailyUsed: info.daily,
        monthlyUsed: info.monthly,
      );

  factory AiException.api(int status, String detail) =>
      AiException(AiErrorKind.api, status: status, detail: detail);

  final AiErrorKind kind;
  final int status;
  final String detail;
  final int dailyUsed;
  final int monthlyUsed;

  /// Mensaje listo para mostrar en una burbuja de error (rioplatense).
  String get friendlyMessage => switch (kind) {
        AiErrorKind.noSession =>
          'No hay sesión activa para usar el asistente. Volvé a iniciar sesión.',
        AiErrorKind.rateLimit => dailyUsed > 0
            ? 'Llegaste al límite de uso del asistente por hoy ($dailyUsed consultas). Volvé mañana o usá las funciones que no necesitan IA.'
            : 'Llegaste al límite de uso del asistente por hoy. Volvé mañana o usá las funciones que no necesitan IA.',
        AiErrorKind.api =>
          'El asistente falló (HTTP $status). Probá de nuevo en un momento.',
        AiErrorKind.invalidResponse =>
          'El asistente devolvió una respuesta inválida. Probá de nuevo.',
        AiErrorKind.network =>
          'No pude conectarme con el asistente. Revisá tu conexión y probá de nuevo.',
        AiErrorKind.toolLoop =>
          'El asistente se quedó dando vueltas. Probá reformulando la pregunta.',
      };

  @override
  String toString() => 'AiException($kind, status: $status): $detail';
}

/// Provider del [AnthropicProxyProvider]. Singleton sin estado (la sesión y el
/// cliente Supabase son globales).
final anthropicProxyProvider = Provider<AnthropicProxyProvider>(
  (ref) => const AnthropicProxyProvider(),
);
