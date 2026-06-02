import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_init.dart';
import '../../../state/app_providers.dart';
import '../../../state/settings_providers.dart';
import '../data/ai_tools.dart';
import '../data/anthropic_proxy_provider.dart';
import '../domain/ai_prompts.dart';
import '../domain/chat_message.dart';
import '../domain/financial_context.dart';

/// Estado del chat del Asistente IA. Plano e inmutable (sin freezed/codegen).
class AssistantState {
  const AssistantState({
    this.messages = const <ChatMessage>[],
    this.isThinking = false,
  });

  /// Historial visible de la conversación (orden cronológico).
  final List<ChatMessage> messages;

  /// `true` mientras hay un turno en vuelo (la UI muestra el typing indicator).
  final bool isThinking;

  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isThinking,
  }) =>
      AssistantState(
        messages: messages ?? this.messages,
        isThinking: isThinking ?? this.isThinking,
      );
}

/// Controller del chat del asistente.
///
/// Orquesta el turno completo: arma el system prompt (con `FinancialContext`
/// live), toma el historial reciente (cap 8 turnos), llama al proxy y corre el
/// loop `tool_use → tool_result → continue` client-side (≤10 iteraciones),
/// exactamente como `AnthropicProvider.respond` de iOS. Aplica el scrub de
/// identidad (`AiPrompts.rebrand`) a todo texto del modelo antes de mostrarlo.
class AssistantController extends Notifier<AssistantState> {
  /// Máximo de iteraciones del loop de tools (igual que iOS).
  static const int _maxToolLoopIterations = 10;

  /// Cuántos turnos de historial visible se envían al modelo (cap chat = 8).
  static const int _historyTurnCap = 8;

  @override
  AssistantState build() => const AssistantState();

  /// Envía [userText] al asistente y resuelve el turno (con tools).
  ///
  /// Nunca lanza: cualquier fallo se degrada a una burbuja de error amigable.
  Future<void> send(String userText) async {
    final String text = userText.trim();
    if (text.isEmpty || state.isThinking) return;

    // 1) Append user msg + thinking on.
    final List<ChatMessage> base = <ChatMessage>[
      ...state.messages,
      ChatMessage(role: ChatRole.user, text: text, createdAt: DateTime.now()),
    ];
    state = state.copyWith(messages: base, isThinking: true);

    try {
      // 2) Resolver hogar + usuario.
      final String? householdId =
          await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
      final String? userId =
          supabaseReady ? supabase.auth.currentUser?.id : null;
      if (householdId == null || userId == null) {
        _appendError(
            'Necesitás un hogar activo y una sesión iniciada para usar el asistente.');
        return;
      }

      // 3) Construir contexto financiero + system prompt.
      final FinancialContext fc = await FinancialContextBuilder.build(ref);
      // Locale efectivo: override del usuario (Ajustes) o, si no hay, el del
      // device. Define la variante regional de la IA (es-ES vs es-AR vs es-419,
      // pt-BR…). Ver AiPrompts.languageVariantPhrase.
      final Locale? localeOverride = ref.read(localeOverrideProvider);
      final Locale resolvedLocale =
          localeOverride ?? PlatformDispatcher.instance.locale;
      final String system = AiPrompts.build(
        financialContextBlock: fc.render(),
        currency: fc.currency,
        locale: resolvedLocale,
      );

      // 4) Historial Anthropic: últimos N turnos visibles (texto user/assistant),
      //    excluyendo burbujas de error y de tool-result. Más el nuevo user msg.
      final List<Map<String, dynamic>> messages = _historyToAnthropic(base);

      // 5) Tool executor + schemas.
      final FinanceToolExecutor executor = FinanceToolExecutor(
        ref: ref,
        householdId: householdId,
        userId: userId,
        currency: fc.currency,
      );
      final List<Map<String, dynamic>> tools = AiToolSchemas.all();
      final AnthropicProxyProvider proxy = ref.read(anthropicProxyProvider);

      // 6) Loop de tool calling (≤10 iteraciones).
      for (int iter = 0; iter < _maxToolLoopIterations; iter++) {
        final AiTurn turn = await proxy.respond(
          system: system,
          messages: messages,
          tools: tools,
        );

        // Si pidió tools, ejecutarlas y continuar.
        if (turn.stopReason == 'tool_use' && turn.toolUses.isNotEmpty) {
          // Si vino texto junto al tool_use, mostralo (rebrandeado).
          if (turn.text.trim().isNotEmpty) {
            _appendAssistant(AiPrompts.rebrand(turn.text));
          }

          // assistant turn con los bloques crudos (tool_use incluidos).
          messages.add(<String, dynamic>{
            'role': 'assistant',
            'content': turn.rawContent,
          });

          // Ejecutar cada tool_use → bloque tool_result.
          final List<Map<String, dynamic>> toolResults =
              <Map<String, dynamic>>[];
          for (final AiToolUse tu in turn.toolUses) {
            final String result = await executor.execute(tu.name, tu.input);
            // Burbuja visible con la clasificación ✅/⚠️/❌.
            _appendToolResult(result);
            toolResults.add(<String, dynamic>{
              'type': 'tool_result',
              'tool_use_id': tu.id,
              'content': result,
            });
          }

          // user turn con los tool_result.
          messages.add(<String, dynamic>{
            'role': 'user',
            'content': toolResults,
          });
          continue;
        }

        // Turno terminado (end_turn / max_tokens / stop_sequence): texto final.
        final String finalText = AiPrompts.rebrand(turn.text);
        if (finalText.trim().isNotEmpty) {
          _appendAssistant(finalText);
        } else if (!_lastIsVisibleAssistant()) {
          // El modelo no devolvió texto y no hubo respuesta previa visible.
          _appendAssistant('Listo. ¿Querés que profundice en algo puntual?');
        }
        return;
      }

      // Loop excedido.
      _appendError(const AiException(AiErrorKind.toolLoop).friendlyMessage);
    } on AiException catch (e) {
      _appendError(e.friendlyMessage);
    } catch (_) {
      _appendError(const AiException(AiErrorKind.network).friendlyMessage);
    } finally {
      if (state.isThinking) {
        state = state.copyWith(isThinking: false);
      }
    }
  }

  /// Limpia la conversación (nuevo chat).
  void clear() => state = const AssistantState();

  // MARK: - Helpers de mutación de estado

  void _appendAssistant(String text) {
    state = state.copyWith(
      messages: <ChatMessage>[
        ...state.messages,
        ChatMessage(
          role: ChatRole.assistant,
          text: text,
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  void _appendToolResult(String result) {
    state = state.copyWith(
      messages: <ChatMessage>[
        ...state.messages,
        ChatMessage(
          role: ChatRole.assistant,
          text: result,
          toolKind: ChatMessage.kindFromToolResult(result),
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  void _appendError(String text) {
    state = state.copyWith(
      messages: <ChatMessage>[
        ...state.messages,
        ChatMessage(
          role: ChatRole.assistant,
          text: text,
          toolKind: ToolResultKind.error,
          isError: true,
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  bool _lastIsVisibleAssistant() {
    if (state.messages.isEmpty) return false;
    final ChatMessage last = state.messages.last;
    return last.role == ChatRole.assistant && !last.isError;
  }

  /// Convierte el historial visible en turnos Anthropic `{role, content}` (texto),
  /// quedándose con los últimos [_historyTurnCap] turnos user/assistant. Excluye
  /// burbujas de error y de tool-result (`toolKind != none`) — esas son ruido
  /// para el modelo (los tool_result reales se threadean dentro del loop).
  List<Map<String, dynamic>> _historyToAnthropic(List<ChatMessage> visible) {
    final List<ChatMessage> turns = visible
        .where((m) =>
            !m.isError &&
            m.toolKind == ToolResultKind.none &&
            (m.role == ChatRole.user || m.role == ChatRole.assistant) &&
            m.text.trim().isNotEmpty)
        .toList();
    final List<ChatMessage> capped = turns.length > _historyTurnCap
        ? turns.sublist(turns.length - _historyTurnCap)
        : turns;
    return capped
        .map((m) => <String, dynamic>{
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
  }
}

/// Provider del controller del asistente.
final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantState>(
        AssistantController.new);
