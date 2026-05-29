import 'dart:ui';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../application/assistant_controller.dart';
import '../domain/chat_message.dart';
import '../voice/voice_conversation_screen.dart';

/// Texto oscuro sobre el sage (burbuja de usuario / botón send) — clavado en iOS.
const Color _kOnSage = Color(0xFF0E1312);

/// Chat del Asistente IA — espejo del `AssistantChatView` (iOS) + IOS_AUDIT §3.
///
/// Modal full-height arrastrable (`showModalBottomSheet` isScrollControlled +
/// [DraggableScrollableSheet] ~0.92) con header glass/blur, fondo en gradiente
/// sutil sage, lista de mensajes (auto-scroll al más nuevo), indicador de
/// "pensando" (3 puntos sage escalonados), chips de sugerencia cuando la
/// conversación está vacía, y barra de input fija abajo (keyboard-safe).
///
/// Consume el "brain" ya construido (`assistantControllerProvider`); esta capa es
/// solo presentación: no orquesta tools ni red.
class AssistantChatSheet extends StatelessWidget {
  const AssistantChatSheet({super.key});

  /// Presenta el chat como hoja modal arrastrable a casi pantalla completa.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // El gradiente + el clip squircle los pinta el contenido; el barrier
      // queda translúcido para el efecto "hoja flotante".
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const AssistantChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) =>
          _ChatBody(dragController: scrollController),
    );
  }
}

// ─────────────────────────────────── Body ───────────────────────────────────

class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody({required this.dragController});

  /// Controller que le da a `DraggableScrollableSheet` el gesto de arrastre. Lo
  /// adjuntamos al `ListView` para que arrastrar la lista expanda/cierre la hoja.
  final ScrollController dragController;

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Re-pinta el botón send/disabled al tipear (canSend depende del texto) y el
    // borde sage de foco del input cuando entra/sale el cursor.
    _inputCtrl.addListener(_onInputChanged);
    _inputFocus.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_onInputChanged);
    _inputFocus.removeListener(_onInputChanged);
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _send(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.lightImpact();
    _inputCtrl.clear();
    // `send` nunca lanza (degrada a burbuja de error). Fire-and-forget: el
    // estado del controller dispara el rebuild con el thinking indicator.
    ref.read(assistantControllerProvider.notifier).send(trimmed);
    // El listener del estado hace el auto-scroll al aparecer el nuevo mensaje.
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final AssistantState chat = ref.watch(assistantControllerProvider);
    final bool isThinking = chat.isThinking;

    // Auto-scroll al fondo cuando cambia la cantidad de mensajes o el thinking.
    ref.listen<AssistantState>(assistantControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.isThinking != next.isThinking) {
        _scrollToBottom();
      }
    });

    return ClipRRect(
      // Esquinas superiores squircle (la hoja "emerge" desde abajo).
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(Radii.hero)),
      child: Container(
        // Fondo en gradiente sutil sage — espejo del `backgroundGradient` (iOS):
        // [appBackground, brandPrimary@0.05, appBackground].
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.appBackground,
              c.brandPrimary.withValues(alpha: 0.05),
              c.appBackground,
            ],
          ),
        ),
        child: Column(
          children: [
            _header(context, c),
            Expanded(
              child: chat.messages.isEmpty && !isThinking
                  ? _emptyConversation(c)
                  : _messageList(c, chat.messages, isThinking),
            ),
            _inputBar(c, isThinking),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────── Header ──────────────────────────────────

  Widget _header(BuildContext context, MidnightSageColors c) {
    return ClipRect(
      child: BackdropFilter(
        // Glass/blur del header — espejo del `.ultraThinMaterial` (iOS toolbar).
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Insets.screen,
            Insets.xl,
            Insets.md,
            Insets.xl,
          ),
          decoration: BoxDecoration(
            color: c.appSurface.withValues(alpha: 0.6),
            border: Border(
              bottom: BorderSide(color: c.appBorder, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Avatar sage con sparkles + anillo champagne (igual que iOS).
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.brandPrimary,
                    border: Border.all(
                      color: c.brandSecondary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(LucideIcons.sparkles,
                      size: 15, color: _kOnSage),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Título serif (editorial), igual que el headline del iOS.
                      Text('Asistente IA',
                          style: AppText.serifTitle(c.textPrimary)
                              .copyWith(fontSize: 20)),
                      Text(
                        'Tu copiloto financiero',
                        style: AppText.caption(c.textMuted),
                      ),
                    ],
                  ),
                ),
                // Botón "nuevo chat" (clear). Solo útil si hay conversación.
                if (ref.watch(assistantControllerProvider).messages.isNotEmpty)
                  _circleIconButton(
                    c,
                    icon: LucideIcons.eraser,
                    tooltip: 'Nuevo chat',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(assistantControllerProvider.notifier).clear();
                    },
                  ),
                const SizedBox(width: Insets.xs),
                // Botón cerrar (glass circle).
                _circleIconButton(
                  c,
                  icon: LucideIcons.x,
                  tooltip: 'Cerrar',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIconButton(
    MidnightSageColors c, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.appSurfaceInset,
        shape: CircleBorder(
          side: BorderSide(color: c.appBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 17, color: c.textPrimary),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── Message list ─────────────────────────────

  Widget _messageList(
    MidnightSageColors c,
    List<ChatMessage> messages,
    bool isThinking,
  ) {
    // Render normal (no reverse): el item extra al final es el thinking bubble.
    final int extra = isThinking ? 1 : 0;
    return ListView.separated(
      controller: widget.dragController,
      padding: const EdgeInsets.fromLTRB(
        Insets.card,
        Insets.xl,
        Insets.card,
        Insets.xl,
      ),
      itemCount: messages.length + extra,
      separatorBuilder: (_, __) => const SizedBox(height: Insets.card),
      itemBuilder: (context, index) {
        if (isThinking && index == messages.length) {
          return const _ThinkingBubble();
        }
        return _MessageBubble(message: messages[index]);
      },
    );
  }

  // ───────────────────────── Empty conversation ────────────────────────────

  Widget _emptyConversation(MidnightSageColors c) {
    return ListView(
      controller: widget.dragController,
      padding: const EdgeInsets.fromLTRB(
        Insets.card,
        Insets.xxl,
        Insets.card,
        Insets.xl,
      ),
      children: [
        // Saludo de bienvenida (espejo del welcome message del iOS).
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.brandPrimary.withValues(alpha: 0.14),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.sparkles, size: 30, color: c.brandPrimary),
          ),
        ),
        const SizedBox(height: Insets.section),
        Text(
          'Hola, soy tu Asistente de Home Finance',
          textAlign: TextAlign.center,
          style: AppText.serifTitle(c.textPrimary),
        ),
        const SizedBox(height: Insets.md),
        Text(
          'Preguntame por tus gastos, presupuesto o metas. '
          'También puedo cargar movimientos por vos.',
          textAlign: TextAlign.center,
          style: AppText.body(c.textMuted),
        ),
        const SizedBox(height: Insets.xxl),
        Text('Para empezar', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.xl),
        ..._suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: Insets.lg),
            child: _SuggestionCard(
              icon: s.icon,
              text: s.text,
              onTap: () => _send(s.text),
            ),
          ),
        ),
      ],
    );
  }

  /// Sugerencias rápidas (rioplatense), espejo del `suggestionsList` del iOS.
  static const List<_Suggestion> _suggestions = <_Suggestion>[
    _Suggestion(LucideIcons.trendingUp, '¿En qué gasté más este mes?'),
    _Suggestion(LucideIcons.pieChart, '¿Cuánto me queda?'),
    _Suggestion(LucideIcons.receipt, 'Gasté 5000 en super'),
    _Suggestion(LucideIcons.calendar, '¿Qué vencimientos tengo?'),
  ];

  // ─────────────────────────────── Input bar ───────────────────────────────

  Widget _inputBar(MidnightSageColors c, bool isThinking) {
    final bool canSend = _inputCtrl.text.trim().isNotEmpty && !isThinking;
    return Container(
      // Color sólido (no blur) — en el input bar el blur puede atrasar el
      // hit-testing de los botones (lección documentada en el iOS).
      decoration: BoxDecoration(
        color: c.appSurface,
        border: Border(top: BorderSide(color: c.appBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        // Keyboard-safe: empujamos el contenido por encima del teclado.
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Insets.xl,
            Insets.lg,
            Insets.xl,
            Insets.lg + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mic → modo voz manos-libres (espejo del botón de voz del iOS).
              _micButton(c, isThinking),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Container(
                  decoration: ShapeDecoration(
                    color: c.appSurfaceInset,
                    shape: SmoothRectangleBorder(
                      borderRadius: Radii.smooth(22),
                      side: BorderSide(
                        color: _inputFocus.hasFocus
                            ? c.brandPrimary.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.screen,
                    vertical: Insets.md,
                  ),
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                    enabled: !isThinking,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: AppText.body(c.textPrimary),
                    cursorColor: c.brandPrimary,
                    decoration: InputDecoration.collapsed(
                      hintText:
                          isThinking ? 'Pensando…' : 'Escribí tu pregunta…',
                      hintStyle: AppText.body(c.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              _sendButton(c, canSend),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón de micrófono → abre el modo voz manos-libres
  /// ([VoiceConversationScreen]). Glass circle a la izquierda del input, mismo
  /// tamaño que el botón de enviar. Deshabilitado mientras el asistente piensa
  /// (no abrimos voz en medio de un turno de texto en vuelo).
  Widget _micButton(MidnightSageColors c, bool isThinking) {
    return Opacity(
      opacity: isThinking ? 0.4 : 1,
      child: Material(
        color: c.appSurfaceInset,
        shape: CircleBorder(side: BorderSide(color: c.appBorder, width: 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isThinking
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  VoiceConversationScreen.show(context);
                },
          child: Tooltip(
            message: 'Hablar con el asistente',
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(LucideIcons.mic, size: 22, color: c.brandPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sendButton(MidnightSageColors c, bool canSend) {
    return Opacity(
      opacity: canSend ? 1 : 0.4,
      child: Material(
        color: c.brandPrimary,
        shape: CircleBorder(
          side: BorderSide(
              color: c.brandSecondary.withValues(alpha: 0.4), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canSend ? () => _send(_inputCtrl.text) : null,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(LucideIcons.arrowUp, size: 22, color: _kOnSage),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────── Scroll ──────────────────────────────────

  void _scrollToBottom() {
    // Espera al frame para que el ListView ya tenga el nuevo extent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.dragController.hasClients) return;
      widget.dragController.animateTo(
        widget.dragController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

// ─────────────────────────────── Suggestion ─────────────────────────────────

class _Suggestion {
  const _Suggestion(this.icon, this.text);
  final IconData icon;
  final String text;
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.appSurface,
      shape: SmoothRectangleBorder(
        borderRadius: Radii.smooth(Radii.input),
        side: BorderSide(color: c.appBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.card,
            vertical: Insets.xl,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.brandPrimary.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: c.brandPrimary),
              ),
              const SizedBox(width: Insets.xl),
              Expanded(
                child: Text(text, style: AppText.body(c.textPrimary)),
              ),
              Icon(LucideIcons.arrowUpRight, size: 15, color: c.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Message bubble ─────────────────────────────

/// Burbuja de un mensaje. Recipe (IOS_AUDIT §3 + `MessageRow` del iOS):
/// - user → derecha, fill `brandPrimary`, texto `#0E1312`, radio 18 squircle.
/// - assistant → izquierda, fill `appSurface`, borde `appBorder` 1pt, radio 18.
/// - tool-result (`toolKind != none`) → card icon+texto, fondo `kind.color@0.08`,
///   stroke `kind.color@0.3`, radio 14.
/// - error (`isError`) → tinte danger.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool isUser = message.role == ChatRole.user;

    // Tool-result (incluye error, que llega como toolKind.error): card especial.
    if (message.toolKind != ToolResultKind.none) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _toolCard(c),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.card,
            vertical: Insets.lg,
          ),
          decoration: ShapeDecoration(
            color: isUser ? c.brandPrimary : c.appSurface,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.card),
              side: BorderSide(
                color: isUser ? Colors.transparent : c.appBorder,
                width: 1,
              ),
            ),
          ),
          child: SelectableText(
            message.text,
            // markdown-ish: render plano (sin dependencia de markdown), igual de
            // legible para prosa y listas con viñetas que ya manda el modelo.
            style: AppText.body(isUser ? _kOnSage : c.textPrimary),
          ),
        ),
      ),
    );
  }

  /// Card de resultado de tool / error. Color por `kind`:
  /// success=brandSuccess · warning=brandWarning · error=brandDanger.
  Widget _toolCard(MidnightSageColors c) {
    final Color accent = switch (message.toolKind) {
      ToolResultKind.success => c.brandSuccess,
      ToolResultKind.warning => c.brandWarning,
      ToolResultKind.error => c.brandDanger,
      ToolResultKind.none => c.appBorder, // inalcanzable (filtrado arriba)
    };
    final IconData icon = switch (message.toolKind) {
      ToolResultKind.success => LucideIcons.checkCircle2,
      ToolResultKind.warning => LucideIcons.alertTriangle,
      ToolResultKind.error => LucideIcons.xCircle,
      ToolResultKind.none => LucideIcons.info,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.card,
          vertical: Insets.xl,
        ),
        decoration: ShapeDecoration(
          color: accent.withValues(alpha: 0.08),
          shape: SmoothRectangleBorder(
            borderRadius: Radii.smooth(Radii.pill),
            side: BorderSide(color: accent.withValues(alpha: 0.3), width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: Insets.xl),
            Flexible(
              child: SelectableText(
                _stripStatusEmoji(message.text),
                style: AppText.body(c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quita el emoji de status prefijo (✅/⚠️/❌) — el icono de la card ya lo
  /// representa (mismo criterio que `contentStrippedOfEmoji` del iOS).
  static String _stripStatusEmoji(String text) {
    final String t = text.trimLeft();
    for (final String prefix in const ['✅', '⚠️', '⚠', '❌']) {
      if (t.startsWith(prefix)) {
        return t.substring(prefix.length).trimLeft();
      }
    }
    return t;
  }
}

// ─────────────────────────────── Thinking bubble ────────────────────────────

/// Indicador de "pensando": 3 puntos sage pulsando en cascada, dentro de una
/// burbuja estilo assistant. Espejo del `thinkingBubble` del iOS.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.card,
          vertical: Insets.xl,
        ),
        decoration: ShapeDecoration(
          color: c.appSurface,
          shape: SmoothRectangleBorder(
            borderRadius: Radii.smooth(Radii.card),
            side: BorderSide(color: c.appBorder, width: 1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: Insets.sm),
              _dot(c, i),
            ],
            const SizedBox(width: Insets.lg),
            Text('Pensando…', style: AppText.caption(c.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _dot(MidnightSageColors c, int index) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Onda escalonada: cada punto desfasado 0.15 del ciclo (igual que iOS).
        final double phase = (_ctrl.value - index * 0.15) % 1.0;
        // Triángulo 0→1→0 para un pulso suave (sin librerías).
        final double t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
        final double scale = 0.55 + 0.45 * t;
        final double opacity = 0.35 + 0.65 * t;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.brandPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
