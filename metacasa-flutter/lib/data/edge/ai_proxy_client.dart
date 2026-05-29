import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_init.dart';

/// Cliente del Edge Function `ai-proxy` (chat con Claude Haiku 4.5).
///
/// STUB — la implementación real llega en Fase 6 (asistente de IA). El proxy
/// recibe un JWT (lo adjunta `supabase_flutter`) y hace **streaming SSE** de
/// los tokens de la respuesta de Anthropic. Espejo del `AnthropicProvider` de
/// iOS, que POSTea a `functions/v1/ai-proxy`.
class AiProxyClient {
  AiProxyClient(this._client);

  // ignore: unused_field
  final SupabaseClient _client;

  /// Envía la conversación al proxy y emite los deltas de texto a medida que
  /// llegan por SSE.
  ///
  /// TODO Fase 6: implementar el streaming real.
  ///   - POST a `${supabaseUrl}/functions/v1/ai-proxy` con
  ///     `Authorization: Bearer <token>` (auto vía supabase_flutter) y body
  ///     `{ "messages": [...], "system": "...", "model": "..." }`.
  ///   - Parsear el stream `text/event-stream`: acumular `data:` lines, cortar
  ///     en `[DONE]`, decodificar cada chunk de Anthropic
  ///     (`content_block_delta` → `delta.text`).
  ///   - Devolver un `Stream<String>` (broadcast) con los deltas; propagar
  ///     errores HTTP como excepción tipada.
  ///   - `functions.invoke` NO sirve para SSE (buffea la respuesta); usar
  ///     `http.Client().send(StreamedRequest)` y armar la URL/headers desde el
  ///     cliente Supabase.
  Stream<String> streamChat(List<Map<String, dynamic>> messages) {
    throw UnimplementedError('ai-proxy streaming — TODO Fase 6');
  }
}

/// Provider del [AiProxyClient].
final aiProxyClientProvider = Provider<AiProxyClient>(
  (ref) => AiProxyClient(supabase),
);
