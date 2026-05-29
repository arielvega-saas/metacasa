import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../application/assistant_controller.dart';
import '../domain/chat_message.dart';
import 'voice_service.dart';

/// Fase de la conversación por voz (espejo de `VoiceConversationManager.State`).
enum VoicePhase { idle, listening, thinking, speaking, error }

/// Modo voz manos-libres tipo ChatGPT — conversación bidireccional por audio.
///
/// Port del `VoiceConversationView` (iOS) sobre la marca Midnight Sage:
/// - **Orb sage-glow** central que pulsa y reacciona a la amplitud del mic
///   (listening) / respira (speaking) / queda quieto (thinking).
/// - **Auto-VAD**: el [VoiceService] corta tras ~1.0s de silencio y dispara el
///   turno solo.
/// - **Loop continuo**: escuchar → auto-enviar → pensar → hablar → escuchar.
/// - **Interrupción**: tocar el orb mientras habla corta el TTS y vuelve a
///   escuchar al instante.
///
/// Consume el "brain" ya construido (`assistantControllerProvider`): hace
/// `await send(text)` y, cuando el turno termina, toma el último mensaje
/// `assistant` (texto, no tool/error) para hablarlo. No orquesta tools ni red.
///
/// Requiere consentimiento de IA ya otorgado: el gate del FAB lo resuelve antes
/// de llegar acá (igual que el chat de texto).
class VoiceConversationScreen extends ConsumerStatefulWidget {
  const VoiceConversationScreen({super.key});

  /// Presenta el modo voz a pantalla completa (push opaco, transición fade).
  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const VoiceConversationScreen(),
        transitionsBuilder: (_, Animation<double> anim, __, Widget child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  ConsumerState<VoiceConversationScreen> createState() =>
      _VoiceConversationScreenState();
}

class _VoiceConversationScreenState
    extends ConsumerState<VoiceConversationScreen> {
  VoicePhase _phase = VoicePhase.idle;
  String _userTranscript = '';
  String _assistantReply = '';
  String _errorText = '';
  double _amplitude = 0;

  /// Snapshot del largo del historial ANTES de enviar — para detectar la
  /// respuesta nueva del asistente sin depender de timing.
  int _messagesBeforeSend = 0;

  bool _closed = false;

  VoiceService get _voice => ref.read(voiceServiceProvider);

  @override
  void initState() {
    super.initState();
    // Mantener la pantalla activa: arranca el flujo manos-libres tras el primer
    // frame (cuando ya hay context para permisos del plugin).
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _closed = true;
    // El provider es autoDispose: al desmontar la pantalla se libera el
    // VoiceService (player + reconocedor). Igual paramos por las dudas.
    _voice.stopListening();
    _voice.stopSpeaking();
    super.dispose();
  }

  // ─────────────────────────────── Loop ────────────────────────────────────

  /// Arranca (o reanuda) el ciclo de escucha.
  Future<void> _begin() async {
    if (_closed) return;
    final bool ready = await _voice.initStt(onError: _onVoiceError);
    if (!ready || _closed) return;
    await _listen();
  }

  Future<void> _listen() async {
    if (_closed) return;
    _set(() {
      _phase = VoicePhase.listening;
      _userTranscript = '';
      _amplitude = 0;
    });
    await _voice.startListening(
      onTranscript: (String t) => _set(() => _userTranscript = t),
      onFinal: _onFinalTranscript,
      onAmplitude: (double a) => _set(() => _amplitude = a),
      onError: _onVoiceError,
    );
  }

  Future<void> _onFinalTranscript(String text) async {
    if (_closed) return;
    final String userText = text.trim();
    if (userText.isEmpty) {
      // Silencio sin contenido: seguimos escuchando.
      if (_phase == VoicePhase.listening) await _listen();
      return;
    }

    _set(() {
      _userTranscript = userText;
      _phase = VoicePhase.thinking;
      _assistantReply = '';
    });

    // Snapshot del historial para ubicar la respuesta nueva después del send.
    _messagesBeforeSend = ref.read(assistantControllerProvider).messages.length;

    // El "brain" nunca lanza (degrada a burbuja de error). `send` completa
    // cuando el turno terminó (incluido el loop de tools).
    await ref.read(assistantControllerProvider.notifier).send(userText);
    if (_closed) return;

    final String reply = _latestAssistantReply();
    if (reply.isEmpty) {
      // Sin texto que hablar (p. ej. sólo corrió una tool): volvé a escuchar.
      await _listen();
      return;
    }

    _set(() {
      _assistantReply = reply;
      _phase = VoicePhase.speaking;
    });

    await _voice.speakReply(reply, onError: _onVoiceError);
    if (_closed) return;

    // Terminó de hablar (o lo interrumpieron): volvé a escuchar.
    if (_phase == VoicePhase.speaking) {
      await _listen();
    }
  }

  /// Extrae el texto a hablar: el último mensaje `assistant` aparecido tras el
  /// send que sea prosa (no tool-result, no error). Recorre desde el final.
  String _latestAssistantReply() {
    final List<ChatMessage> messages =
        ref.read(assistantControllerProvider).messages;
    // Buscamos sólo dentro de lo que se agregó en este turno.
    for (int i = messages.length - 1; i >= _messagesBeforeSend; i--) {
      final ChatMessage m = messages[i];
      if (m.role == ChatRole.assistant &&
          !m.isError &&
          m.toolKind == ToolResultKind.none &&
          m.text.trim().isNotEmpty) {
        return m.text.trim();
      }
    }
    return '';
  }

  void _onVoiceError(VoiceError error) {
    if (_closed) return;
    // Un error de TTS no debería matar el loop: avisamos y reintentamos
    // escuchar. Un error de STT (permiso/red) sí frena en estado error.
    if (!error.isStt) {
      // Best-effort: avisamos por SnackBar y seguimos.
      return;
    }
    _set(() {
      _phase = VoicePhase.error;
      _errorText = error.message;
    });
  }

  // ─────────────────────────────── Tap orb ─────────────────────────────────

  /// Tap del orb (espejo de `userTappedOrb`):
  /// - idle/error → empezar a escuchar.
  /// - speaking   → interrumpir el TTS y volver a escuchar al toque.
  /// - thinking   → no-op (esperás la respuesta).
  /// - listening  → no-op (es manos-libres; el silencio corta solo).
  Future<void> _onOrbTap() async {
    HapticFeedback.mediumImpact();
    switch (_phase) {
      case VoicePhase.idle:
      case VoicePhase.error:
        await _begin();
      case VoicePhase.speaking:
        await _voice.stopSpeaking();
        await _listen();
      case VoicePhase.thinking:
      case VoicePhase.listening:
        break;
    }
  }

  Future<void> _close() async {
    HapticFeedback.lightImpact();
    _closed = true;
    await _voice.stopListening();
    await _voice.stopSpeaking();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _set(VoidCallback fn) {
    if (!mounted || _closed) return;
    setState(fn);
  }

  // ─────────────────────────────── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final MidnightSageColors c = context.colors;
    return PopScope(
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) {
          _closed = true;
          _voice.stopListening();
          _voice.stopSpeaking();
        }
      },
      child: Scaffold(
        backgroundColor: c.appBackground,
        body: Stack(
          children: <Widget>[
            _GlowBackground(phase: _phase, amplitude: _amplitude),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: <Widget>[
                    _topBar(c),
                    const Spacer(),
                    _VoiceOrb(
                      phase: _phase,
                      amplitude: _amplitude,
                      onTap: _onOrbTap,
                    ),
                    const Spacer(),
                    _transcriptPanel(c),
                    const SizedBox(height: 12),
                    _bottomHint(c),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(MidnightSageColors c) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Cerrar modo voz',
        child: Material(
          color: c.appSurface.withValues(alpha: 0.6),
          shape: CircleBorder(
            side: BorderSide(color: c.appBorder, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _close,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(LucideIcons.x, size: 20, color: c.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _transcriptPanel(MidnightSageColors c) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 170),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_userTranscript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                VoiceService.sanitizeForTTS(_userTranscript),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(c.textMuted),
              ),
            ),
          if (_assistantReply.isNotEmpty)
            Text(
              VoiceService.sanitizeForTTS(_assistantReply),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _bottomHint(MidnightSageColors c) {
    final String text = switch (_phase) {
      VoicePhase.idle => 'Tocá el círculo y empezá a hablar',
      VoicePhase.listening => 'Te escucho…',
      VoicePhase.thinking => 'Pensando…',
      VoicePhase.speaking => 'Tocá para interrumpir',
      VoicePhase.error => _errorText,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        text,
        key: ValueKey<String>('$_phase$_errorText'),
        textAlign: TextAlign.center,
        style: AppText.caption(
          _phase == VoicePhase.error
              ? c.brandDanger
              : c.textMuted.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Background glow ────────────────────────────

/// Radial sage-glow centrado que respira con la fase y refuerza con la amplitud
/// (espejo del `backgroundLayer` del iOS). Color por fase.
class _GlowBackground extends StatelessWidget {
  const _GlowBackground({required this.phase, required this.amplitude});

  final VoicePhase phase;
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    final MidnightSageColors c = context.colors;
    final Color glow = _glowColor(c, phase);
    final double boost = phase == VoicePhase.listening ? amplitude * 0.15 : 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: <Color>[
            glow.withValues(alpha: 0.30 + boost),
            glow.withValues(alpha: 0.08),
            c.appBackground,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

Color _glowColor(MidnightSageColors c, VoicePhase phase) => switch (phase) {
      VoicePhase.idle => c.brandPrimary.withValues(alpha: 0.5),
      VoicePhase.listening => c.brandPrimary,
      VoicePhase.thinking => c.brandSecondary,
      VoicePhase.speaking => c.brandSuccess,
      VoicePhase.error => c.brandDanger,
    };

// ─────────────────────────────── Voice orb ──────────────────────────────────

/// Orb central reactivo (espejo del `centerOrb`/`ringsLayer`/`solidOrb` de iOS).
///
/// - Anillos exteriores: breathing suave; el del medio reacciona a la amplitud
///   en listening.
/// - Orb sólido: escala con la amplitud (listening), respira lento (speaking),
///   queda quieto (thinking). Gradiente sage con highlight y glow de color.
/// - Icono sólo en idle/thinking/error (en listening/speaking el orb es la
///   animación principal).
class _VoiceOrb extends StatefulWidget {
  const _VoiceOrb({
    required this.phase,
    required this.amplitude,
    required this.onTap,
  });

  final VoicePhase phase;
  final double amplitude;
  final VoidCallback onTap;

  @override
  State<_VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<_VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MidnightSageColors c = context.colors;
    final Color orb = _glowColor(c, widget.phase);
    final double amp = widget.amplitude.clamp(0.0, 1.0);

    return Semantics(
      button: true,
      label: 'Asistente por voz',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 240,
          height: 240,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (BuildContext context, _) {
              final double breath = _breath.value; // 0→1→0
              // Tamaños base por fase + reacción a amplitud / breathing.
              final double orbSize = switch (widget.phase) {
                VoicePhase.idle || VoicePhase.error => 170 + breath * 6,
                VoicePhase.listening => 170 + amp * 28,
                VoicePhase.thinking => 166,
                VoicePhase.speaking => 182 + breath * 12,
              };
              final double midRing = switch (widget.phase) {
                VoicePhase.listening => 210 + amp * 30,
                VoicePhase.thinking || VoicePhase.speaking => 206,
                _ => 200 + breath * 4,
              };
              final double outerRing = switch (widget.phase) {
                VoicePhase.listening => 232 + amp * 8,
                _ => 224 + breath * 6,
              };

              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  _ring(orb.withValues(alpha: 0.18), outerRing, 1.5),
                  _ring(orb.withValues(alpha: 0.32), midRing, 2),
                  _solidOrb(c, orb, orbSize, breath),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _ring(Color color, double size, double stroke) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: stroke),
      ),
    );
  }

  Widget _solidOrb(
    MidnightSageColors c,
    Color orb,
    double size,
    double breath,
  ) {
    final IconData? icon = switch (widget.phase) {
      VoicePhase.idle => LucideIcons.mic,
      VoicePhase.thinking => LucideIcons.sparkles,
      VoicePhase.error => LucideIcons.alertTriangle,
      VoicePhase.listening || VoicePhase.speaking => null,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          radius: 1.0,
          colors: <Color>[orb, orb.withValues(alpha: 0.85)],
        ),
        border: Border.all(color: orb.withValues(alpha: 0.7), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: orb.withValues(alpha: 0.45),
            blurRadius: 26 + breath * 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Highlight interior suave (offset arriba-izquierda).
          Transform.translate(
            offset: Offset(-size * 0.12, -size * 0.12),
            child: Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          if (icon != null)
            _PulsingIcon(
              icon: icon,
              pulsing: widget.phase == VoicePhase.thinking,
              breath: breath,
            ),
        ],
      ),
    );
  }
}

/// Icono central. En thinking late suavemente; resto fijo. Color oscuro sobre
/// sage (mismo `#0E1312` que el resto de los acentos sage de la app).
class _PulsingIcon extends StatelessWidget {
  const _PulsingIcon({
    required this.icon,
    required this.pulsing,
    required this.breath,
  });

  final IconData icon;
  final bool pulsing;
  final double breath;

  static const Color _onSage = Color(0xFF0E1312);

  @override
  Widget build(BuildContext context) {
    final double scale = pulsing ? 0.92 + breath * 0.16 : 1.0;
    return Transform.scale(
      scale: scale,
      child: Icon(icon, size: 42, color: _onSage),
    );
  }
}
