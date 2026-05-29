import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_init.dart';

/// Cliente del Edge Function `tts-proxy` (text-to-speech vía ElevenLabs).
///
/// STUB — la implementación real llega en Fase 6 (voz del asistente). El proxy
/// recibe un JWT (lo adjunta `supabase_flutter`) y devuelve audio sintetizado.
/// Espejo del `CloudTTSService` de iOS, que POSTea a `functions/v1/tts-proxy`.
class TtsProxyClient {
  TtsProxyClient(this._client);

  // ignore: unused_field
  final SupabaseClient _client;

  /// Sintetiza [text] a audio (voz Malena rioplatense) y devuelve los bytes.
  ///
  /// TODO Fase 6: implementar la llamada real.
  ///   - POST a `${supabaseUrl}/functions/v1/tts-proxy` con
  ///     `Authorization: Bearer <token>` (auto vía supabase_flutter) y body
  ///     `{ "text": "...", "voice_id": "p7AwDmKvTdoHTBuueGvP" }`.
  ///   - Respuesta = audio binario (`audio/mpeg`); leer el body como bytes.
  ///   - `functions.invoke` SÍ sirve acá (respuesta no-streamed): el
  ///     `FunctionResponse.data` viene como `Uint8List` cuando el
  ///     `Content-Type` es binario. Manejar non-200 como excepción tipada.
  ///   - Devolver `Uint8List` para reproducir con un player de audio.
  Future<Uint8List> synthesize(String text) {
    throw UnimplementedError('tts-proxy synthesis — TODO Fase 6');
  }
}

/// Provider del [TtsProxyClient].
final ttsProxyClientProvider = Provider<TtsProxyClient>(
  (ref) => TtsProxyClient(supabase),
);
