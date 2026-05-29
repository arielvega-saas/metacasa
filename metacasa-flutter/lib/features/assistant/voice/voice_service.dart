import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../config/env.dart';
import '../../../config/supabase_init.dart';

/// Servicio de voz del Asistente IA — STT + TTS.
///
/// Port del stack de voz del iOS (`SpeechRecognizerService` + `CloudTTSService`
/// + `TTSService`):
///
/// - **STT** vía `speech_to_text` (Android `SpeechRecognizer`). Locale `es-AR`
///   con fallback al device. Resultados parciales en vivo, nivel de audio
///   (amplitud) para animar el orb, y auto-finalize por silencio (`pauseFor`
///   ~1.0s, espejado además con un watchdog propio sobre `lastResult`).
/// - **TTS primario = ElevenLabs Malena** vía la Edge Function `tts-proxy`
///   (`voice_id p7AwDmKvTdoHTBuueGvP`, `model eleven_flash_v2_5`). El proxy
///   devuelve **MP3 con `Content-Type: audio/mpeg`** — por eso NO usamos
///   `functions.invoke` (su cliente hace `utf8.decode` de cualquier body que no
///   sea json/octet-stream y corrompe el binario); pegamos crudo con `http` y
///   los headers que adjunta iOS (`Authorization: Bearer <jwt>` + `apikey`),
///   leyendo `bodyBytes`. Reproducimos con `just_audio` desde memoria mediante
///   un [_BytesAudioSource] (custom `StreamAudioSource`, sin tocar el FS).
///   Split en oraciones + **prefetch** de la siguiente mientras suena la actual
///   (espejo de la cola del `CloudTTSService`).
/// - **Fallback = `flutter_tts`** (TTS on-device) si el `tts-proxy` falla.
/// - [sanitizeForTTS] limpia markdown / emojis / códigos ISO antes de hablar
///   (port de `cleanForSpeech` del `TTSService`).
///
/// Todos los errores de audio degradan con gracia: si el cloud falla cae al
/// fallback; si el STT falla emite [VoiceError]; nunca lanza hacia afuera.
class VoiceService {
  VoiceService();

  // ── ElevenLabs (espejo del CloudTTSService de iOS) ──

  /// Voice id de Malena (nativa rioplatense). Mismo id que iOS y la memoria.
  static const String elevenLabsMalenaVoiceId = 'p7AwDmKvTdoHTBuueGvP';

  /// Modelo flash (baja latencia) — igual que iOS.
  static const String elevenLabsModel = 'eleven_flash_v2_5';

  /// Umbral de silencio para auto-finalizar el dictado (igual que iOS: ~1.0s).
  static const Duration silenceThreshold = Duration(milliseconds: 1000);

  // ── STT ──
  final SpeechToText _stt = SpeechToText();
  bool _sttInitDone = false;
  bool _sttAvailable = false;
  String? _resolvedLocaleId;

  // ── TTS cloud (ElevenLabs vía tts-proxy) ──
  final AudioPlayer _player = AudioPlayer();
  final http.Client _httpClient = http.Client();

  /// Cola de oraciones pendientes de reproducir (FIFO).
  final List<String> _sentenceQueue = <String>[];

  /// Audio MP3 ya descargado por oración (prefetch). La key es la oración.
  final Map<String, Uint8List> _prefetched = <String, Uint8List>{};

  /// Loop que consume [_sentenceQueue]. `null` si no hay nada hablando.
  Future<void>? _queueLoop;

  /// Completers que esperan a que la cola termine (`speakReply` los resuelve).
  final List<Completer<void>> _queueWaiters = <Completer<void>>[];

  /// `true` mientras hay reproducción cloud activa.
  bool _cloudSpeaking = false;

  /// Cancela cualquier reproducción en curso al hacer `stopSpeaking()`.
  bool _ttsCancelled = false;

  // ── TTS fallback (on-device) ──
  FlutterTts? _fallbackTts;
  bool _fallbackInitDone = false;

  // ───────────────────────────────── STT API ─────────────────────────────────

  /// Inicializa el reconocimiento de voz y pide permisos (idempotente).
  ///
  /// Resuelve el `localeId` a usar: prefiere `es-AR`; si el device no lo lista,
  /// cae al `es-*` más cercano y, en última instancia, al locale del sistema.
  /// Devuelve `true` si el STT quedó disponible.
  Future<bool> initStt({
    void Function(VoiceError error)? onError,
  }) async {
    if (_sttInitDone) return _sttAvailable;
    _sttInitDone = true;
    try {
      _sttAvailable = await _stt.initialize(
        onError: (SpeechRecognitionError e) {
          if (!e.permanent) return; // errores transitorios: los ignoramos.
          onError?.call(VoiceError.stt(_friendlySttError(e.errorMsg)));
        },
        onStatus: (_) {},
      );
    } catch (_) {
      _sttAvailable = false;
    }

    if (_sttAvailable) {
      _resolvedLocaleId = await _resolveLocaleId();
    } else {
      onError?.call(const VoiceError.stt(
        'No pude activar el micrófono. Revisá los permisos en Ajustes.',
      ));
    }
    return _sttAvailable;
  }

  /// `true` si el STT está escuchando ahora.
  bool get isListening => _stt.isListening;

  /// Arranca el dictado. Emite parciales por [onTranscript], el nivel de audio
  /// 0–1 por [onAmplitude], y dispara [onFinal] una sola vez cuando se detecta
  /// el final (silencio ~1.0s o `finalResult` del motor) con el texto final.
  ///
  /// El auto-finalize lo maneja `pauseFor`, reforzado por un watchdog propio que
  /// cierra si el transcript no cambia por [silenceThreshold] (algunos motores
  /// Android no respetan `pauseFor` de forma consistente).
  Future<void> startListening({
    required void Function(String transcript) onTranscript,
    required void Function(String finalTranscript) onFinal,
    void Function(double amplitude)? onAmplitude,
    void Function(VoiceError error)? onError,
  }) async {
    final bool ready = await initStt(onError: onError);
    if (!ready) return;
    if (_stt.isListening) return;

    String latest = '';
    DateTime lastChange = DateTime.now();
    bool finalized = false;
    Timer? watchdog;

    void finalize(String text) {
      if (finalized) return;
      finalized = true;
      watchdog?.cancel();
      onFinal(text.trim());
    }

    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          final String words = r.recognizedWords;
          if (words != latest) {
            latest = words;
            lastChange = DateTime.now();
            onTranscript(words);
          }
          if (r.finalResult) finalize(latest);
        },
        onSoundLevelChange: onAmplitude == null
            ? null
            : (double level) => onAmplitude(_normalizeLevel(level)),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          // Locale resuelto (es-AR → es-* → sistema).
          localeId: _resolvedLocaleId,
          // Auto-VAD del motor: corta tras ~1.0s de silencio.
          pauseFor: silenceThreshold,
          // Tope duro defensivo por si el motor nunca corta.
          listenFor: const Duration(seconds: 30),
          cancelOnError: true,
          // On-device cuando esté (privacidad); igual cae a cloud transparente.
          onDevice: false,
        ),
      );
    } catch (_) {
      onError?.call(const VoiceError.stt(
        'No pude activar el micrófono. Cerrá apps que lo estén usando y probá de nuevo.',
      ));
      return;
    }

    // Watchdog: si hay contenido y el transcript no cambió por el umbral,
    // forzamos el final (espejo del `startSilenceMonitor` del iOS).
    watchdog = Timer.periodic(const Duration(milliseconds: 200), (Timer t) {
      if (finalized || !_stt.isListening) {
        t.cancel();
        return;
      }
      final bool hasContent = latest.trim().isNotEmpty;
      final bool quiet =
          DateTime.now().difference(lastChange) >= silenceThreshold;
      if (hasContent && quiet) {
        // Cerramos el motor primero; el `finalize` dispara el turno una vez.
        _stt.stop();
        finalize(latest);
      }
    });
  }

  /// Detiene el dictado sin disparar el final (cancela el turno actual).
  Future<void> cancelListening() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
  }

  /// Detiene el dictado de forma limpia (el motor emite el resultado final si
  /// lo tiene). Usado al interrumpir el modo voz desde afuera.
  Future<void> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  // ───────────────────────────────── TTS API ─────────────────────────────────

  /// `true` mientras se está reproduciendo audio (cloud o fallback).
  bool get isSpeaking =>
      _cloudSpeaking || (_fallbackTts != null && _fallbackSpeaking);
  bool _fallbackSpeaking = false;

  /// Habla [reply] completa: la limpia, la corta en oraciones y las encola al
  /// pipeline ElevenLabs (con prefetch). Si el cloud falla en la PRIMERA
  /// oración, cae al fallback `flutter_tts` con el texto entero.
  ///
  /// Suspende hasta que termina de hablar todo (o hasta que [stopSpeaking] lo
  /// interrumpe). No lanza.
  Future<void> speakReply(
    String reply, {
    void Function(VoiceError error)? onError,
  }) async {
    final String cleaned = sanitizeForTTS(reply);
    if (cleaned.isEmpty) return;

    _ttsCancelled = false;

    final String? token = _accessToken();
    final List<String> sentences = _splitIntoSentences(cleaned);

    // Sin sesión o sin backend → directo al fallback on-device.
    if (token == null || !Env.hasSupabase) {
      await _speakFallback(cleaned, onError: onError);
      return;
    }

    _sentenceQueue
      ..clear()
      ..addAll(sentences);
    _prefetched.clear();
    _kickPrefetch(token);

    final Completer<void> done = Completer<void>();
    _queueWaiters.add(done);
    _queueLoop ??= _runQueue(token, cleaned, onError);
    await done.future;
  }

  /// Detiene cualquier reproducción (cloud + fallback) y limpia la cola.
  /// Se usa para interrumpir al asistente y volver a escuchar.
  ///
  /// Espera a que el loop de la cola termine de desmontarse antes de volver,
  /// para que un `speakReply` inmediatamente posterior (próximo turno) arranque
  /// un loop nuevo y no quede pegado al viejo (evita un race con `_queueLoop`).
  Future<void> stopSpeaking() async {
    _ttsCancelled = true;
    _sentenceQueue.clear();
    _prefetched.clear();
    _cloudSpeaking = false;
    try {
      await _player.stop();
    } catch (_) {/* ignore */}
    if (_fallbackTts != null) {
      _fallbackSpeaking = false;
      try {
        await _fallbackTts!.stop();
      } catch (_) {/* ignore */}
    }
    // Despierta a quien esté esperando la cola (resuelve su `speakReply`)…
    _drainWaiters();
    // …y espera a que el loop en vuelo corra su `finally` y se anule, pero con
    // un tope corto: si está colgado en un `_fetchAudio` (red), no bloqueamos la
    // interrupción — el `finally` del loop igual lo anula al volver del await.
    final Future<void>? loop = _queueLoop;
    if (loop != null) {
      try {
        await loop.timeout(const Duration(milliseconds: 300));
      } catch (_) {/* timeout o error: el loop se desmonta solo */}
    }
  }

  // ── Cola de oraciones (espejo del CloudTTSService.startQueueProcessor) ──

  Future<void> _runQueue(
    String token,
    String fullTextForFallback,
    void Function(VoiceError error)? onError,
  ) async {
    bool firstSentence = true;
    try {
      while (_sentenceQueue.isNotEmpty && !_ttsCancelled) {
        final String sentence = _sentenceQueue.removeAt(0);
        _kickPrefetch(token); // descarga las próximas mientras suena esta.

        Uint8List? audio = _prefetched.remove(sentence);
        audio ??= await _fetchAudio(sentence, token);

        if (_ttsCancelled) break;

        if (audio == null) {
          // El cloud falló. En la primera oración caemos al fallback con el
          // texto entero (igual que iOS); si ya venía hablando, cortamos.
          if (firstSentence) {
            await _speakFallback(fullTextForFallback, onError: onError);
          } else {
            onError?.call(const VoiceError.tts(
              'Se cortó la voz del asistente.',
            ));
          }
          break;
        }

        firstSentence = false;
        await _playBytes(audio);
        if (_ttsCancelled) break;
      }
    } finally {
      _cloudSpeaking = false;
      _queueLoop = null;
      _drainWaiters();
    }
  }

  /// Descarga eager hasta 2 oraciones por delante (amortigua latencia).
  void _kickPrefetch(String token) {
    final List<String> next = _sentenceQueue.take(2).toList();
    for (final String sentence in next) {
      if (_prefetched.containsKey(sentence)) continue;
      // Marca temprana para no lanzar dos descargas de la misma oración.
      _prefetched[sentence] = Uint8List(0);
      unawaited(() async {
        final Uint8List? audio = await _fetchAudio(sentence, token);
        if (audio != null && !_ttsCancelled) {
          _prefetched[sentence] = audio;
        } else {
          _prefetched.remove(sentence);
        }
      }());
    }
  }

  /// POST crudo al `tts-proxy`. Devuelve los bytes MP3, o `null` si falló.
  ///
  /// Se replica el contrato del `fetchAudio` de iOS: headers `Authorization`
  /// + `apikey`, body `{text, provider:'elevenlabs', voice_id, el_model, ...}`.
  /// El proxy responde `audio/mpeg`; un error vuelve como JSON (lo detectamos
  /// por status / content-type y devolvemos `null` para degradar al fallback).
  Future<Uint8List?> _fetchAudio(String text, String token) async {
    if (Env.supabaseUrl.isEmpty) return null;
    final Uri url = Uri.parse('${Env.supabaseUrl}/functions/v1/tts-proxy');
    try {
      final http.Response res = await _httpClient
          .post(
            url,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'apikey': Env.supabaseAnonKey,
            },
            // stability/style: mismos valores afinados del iOS para español.
            body: _jsonBody(text),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) return null;
      final String type = (res.headers['content-type'] ?? '').toLowerCase();
      // Defensa: si por algún motivo vuelve json (error), no es audio.
      if (type.contains('application/json')) return null;
      final Uint8List bytes = res.bodyBytes;
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  String _jsonBody(String text) {
    // Construido a mano para no importar dart:convert sólo por esto;
    // el texto ya viene saneado (sin comillas/markdown problemáticos), pero
    // escapamos comillas y barras por las dudas.
    final String safe = text
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    return '{"text":"$safe","provider":"elevenlabs",'
        '"voice_id":"$elevenLabsMalenaVoiceId","el_model":"$elevenLabsModel",'
        '"stability":0.45,"similarity_boost":0.85,"style":0.15}';
  }

  /// Reproduce un buffer MP3 con `just_audio` y suspende hasta que termina.
  Future<void> _playBytes(Uint8List bytes) async {
    try {
      _cloudSpeaking = true;
      await _player.setAudioSource(_BytesAudioSource(bytes));
      // Espera el `completed` del stream de estado (o un stop externo).
      final Completer<void> finished = Completer<void>();
      late final StreamSubscription<PlayerState> sub;
      sub = _player.playerStateStream.listen((PlayerState s) {
        if (s.processingState == ProcessingState.completed) {
          if (!finished.isCompleted) finished.complete();
        }
      });
      unawaited(_player.play());
      // Si nos cancelan, `stopSpeaking` para el player → el estado no llega a
      // completed, así que también escuchamos la bandera con un poll corto.
      while (!finished.isCompleted && !_ttsCancelled) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      await sub.cancel();
    } catch (_) {
      // Decode/playback error: lo tratamos como fin de esta oración.
    } finally {
      _cloudSpeaking = false;
    }
  }

  // ── Fallback on-device (flutter_tts) ──

  Future<void> _ensureFallback() async {
    if (_fallbackInitDone) return;
    _fallbackInitDone = true;
    final FlutterTts tts = FlutterTts();
    try {
      await tts.setLanguage('es-AR');
    } catch (_) {
      try {
        await tts.setLanguage('es-ES');
      } catch (_) {/* deja el default del device */}
    }
    // Un poco más lento que el default — más comprensible para finanzas (iOS).
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);
    _fallbackTts = tts;
  }

  Future<void> _speakFallback(
    String text, {
    void Function(VoiceError error)? onError,
  }) async {
    try {
      await _ensureFallback();
      if (_ttsCancelled || _fallbackTts == null) return;
      _fallbackSpeaking = true;
      // `awaitSpeakCompletion(true)` hace que `speak` resuelva al terminar.
      await _fallbackTts!.speak(text);
    } catch (_) {
      onError?.call(const VoiceError.tts(
        'No pude reproducir la respuesta por voz.',
      ));
    } finally {
      _fallbackSpeaking = false;
    }
  }

  // ───────────────────────────────── Helpers ─────────────────────────────────

  void _drainWaiters() {
    final List<Completer<void>> waiters =
        List<Completer<void>>.from(_queueWaiters);
    _queueWaiters.clear();
    for (final Completer<void> w in waiters) {
      if (!w.isCompleted) w.complete();
    }
  }

  String? _accessToken() {
    if (!supabaseReady) return null;
    return supabase.auth.currentSession?.accessToken;
  }

  /// Normaliza el nivel de `onSoundLevelChange` a 0–1.
  ///
  /// `speech_to_text` reporta dBFS aproximados (Android suele dar ~ -2..10,
  /// iOS ~ -160..0). Mapeamos un rango útil de voz a 0–1 de forma robusta para
  /// ambos: clamp a [-2, 10] tras tratar negativos grandes como silencio.
  double _normalizeLevel(double raw) {
    if (raw.isNaN) return 0;
    // dBFS muy negativo (iOS) → silencio.
    if (raw <= -50) return 0;
    final double v = raw < 0 ? (raw + 50) / 50 * 10 : raw; // reescala iOS
    final double clamped = v.clamp(0.0, 10.0);
    return clamped / 10.0;
  }

  /// Resuelve el `localeId` preferido: `es-AR` → `es-*` → locale del sistema.
  Future<String?> _resolveLocaleId() async {
    try {
      final List<LocaleName> locales = await _stt.locales();
      if (locales.isEmpty) return 'es_AR';
      bool has(String id) => locales.any((LocaleName l) =>
          l.localeId.replaceAll('-', '_').toLowerCase() == id.toLowerCase());
      if (has('es_AR')) return 'es_AR';
      // Cualquier español disponible.
      final LocaleName? es = locales.cast<LocaleName?>().firstWhere(
            (LocaleName? l) =>
                l != null && l.localeId.toLowerCase().startsWith('es'),
            orElse: () => null,
          );
      if (es != null) return es.localeId;
      final LocaleName system = await _stt.systemLocale() ?? locales.first;
      return system.localeId;
    } catch (_) {
      return 'es_AR';
    }
  }

  String _friendlySttError(String code) {
    // Mensajes amigables en rioplatense para los errores típicos del motor.
    switch (code) {
      case 'error_no_match':
      case 'error_speech_timeout':
        return 'No te escuché bien. Probá de nuevo.';
      case 'error_permission':
      case 'error_audio':
        return 'Necesito permiso de micrófono. Activalo en Ajustes.';
      case 'error_network':
      case 'error_network_timeout':
        return 'Sin conexión para reconocer la voz. Revisá tu internet.';
      default:
        return 'Hubo un problema con el micrófono. Probá de nuevo.';
    }
  }

  /// Corta texto en oraciones por `. ! ? \n` (igual que `splitIntoSentences`
  /// del iOS). Cada oración se descarga por separado para el prefetch.
  List<String> _splitIntoSentences(String text) {
    final List<String> sentences = <String>[];
    final StringBuffer current = StringBuffer();
    const Set<String> terminators = <String>{'.', '!', '?', '\n'};
    for (final String ch in text.split('')) {
      current.write(ch);
      if (terminators.contains(ch)) {
        final String trimmed = current.toString().trim();
        if (trimmed.isNotEmpty) sentences.add(trimmed);
        current.clear();
      }
    }
    final String leftover = current.toString().trim();
    if (leftover.isNotEmpty) sentences.add(leftover);
    return sentences.isEmpty ? <String>[text] : sentences;
  }

  /// Limpia markdown, emojis, símbolos y códigos ISO de moneda antes de hablar.
  /// Port 1:1 de `cleanForSpeech` (`TTSService` / `CloudTTSService` de iOS) para
  /// que la voz no lea "asterisco asterisco" ni "ARS".
  static String sanitizeForTTS(String text) {
    String result = text;

    // **bold** → bold
    result = result.replaceAll('**', '');
    // *italic* → italic (sólo asteriscos rodeando palabras, no rompe "más*").
    result = result.replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1');
    // [texto](url) → texto
    result = result.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    // `code` → code
    result = result.replaceAll('`', '');

    // Emojis: los sacamos (no se leen, pero generan pausas raras).
    result = result.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}]',
        unicode: true,
      ),
      '',
    );

    // Símbolos que se leerían mal.
    result = result.replaceAll('→', ' a ');
    result = result.replaceAll('·', ', ');
    result = result.replaceAll('—', ', ');
    result = result.replaceAll('–', ', ');

    // Códigos ISO de moneda → palabra hablada (red de seguridad).
    const Map<String, String> isoMappings = <String, String>{
      'ARS': 'pesos',
      'CLP': 'pesos',
      'COP': 'pesos',
      'MXN': 'pesos',
      'UYU': 'pesos',
      'USD': 'dólares',
      'EUR': 'euros',
      'BRL': 'reales',
      'GBP': 'libras',
      'JPY': 'yenes',
      'PEN': 'soles',
    };
    isoMappings.forEach((String iso, String spoken) {
      result = result.replaceAll(RegExp('\\b$iso\\b'), spoken);
    });

    // Newlines → punto + espacio.
    result = result.replaceAll('\n\n', '. ').replaceAll('\n', '. ');

    // Colapsar espacios dobles.
    while (result.contains('  ')) {
      result = result.replaceAll('  ', ' ');
    }

    return result.trim();
  }

  /// Libera recursos (player + http + fallback). Idempotente.
  Future<void> dispose() async {
    _ttsCancelled = true;
    _sentenceQueue.clear();
    _prefetched.clear();
    _drainWaiters();
    try {
      await _player.dispose();
    } catch (_) {/* ignore */}
    try {
      await _fallbackTts?.stop();
    } catch (_) {/* ignore */}
    _httpClient.close();
  }
}

/// `StreamAudioSource` que sirve un buffer MP3 en memoria a `just_audio` sin
/// escribir al filesystem. Soporta range requests (el plugin las pide para el
/// scrubbing), devolviendo el sub-rango pedido del [_bytes].
class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes);

  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final int from = start ?? 0;
    final int to = end ?? _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: to - from,
      offset: from,
      stream: Stream<List<int>>.value(_bytes.sublist(from, to)),
      contentType: 'audio/mpeg',
    );
  }
}

/// Error de voz tipado (rioplatense, listo para mostrar). Distingue STT de TTS
/// para que la UI pueda decidir si reintenta escuchar o sólo avisa.
@immutable
class VoiceError {
  const VoiceError._(this.message, this.isStt);
  const VoiceError.stt(String message) : this._(message, true);
  const VoiceError.tts(String message) : this._(message, false);

  final String message;
  final bool isStt;

  @override
  String toString() => 'VoiceError(${isStt ? 'stt' : 'tts'}): $message';
}

/// Provider del [VoiceService]. `autoDispose` para liberar el `AudioPlayer` y el
/// reconocedor cuando se cierra la pantalla de voz (no hay otro consumidor).
final voiceServiceProvider = Provider.autoDispose<VoiceService>((Ref ref) {
  final VoiceService service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});
