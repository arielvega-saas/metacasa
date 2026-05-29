import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';

/// Color de texto sobre el sage glow del primario — clavado en el iOS (`#0E1312`).
const Color _kOnPrimary = Color(0xFF0E1312);

/// Base interna compartida por los dos botones MC: maneja el press (scale 0.97
/// con spring, igual que iOS) + selection haptic + estado disabled.
///
/// No es parte de la API pública; usar [MCPrimaryButton] / [MCSecondaryButton].
class _MCButtonBase extends StatefulWidget {
  const _MCButtonBase({
    required this.onPressed,
    required this.decoration,
    required this.minHeight,
    required this.textStyle,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final ShapeDecoration decoration;
  final double minHeight;
  final TextStyle textStyle;
  final String label;
  final IconData? icon;

  @override
  State<_MCButtonBase> createState() => _MCButtonBaseState();
}

class _MCButtonBaseState extends State<_MCButtonBase> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: widget.textStyle.color),
          const SizedBox(width: Insets.md),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: widget.textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: Opacity(
        // Disabled: atenuamos en vez de cambiar de color (mantiene la firma sage).
        opacity: _enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            _setPressed(true);
            HapticFeedback.selectionClick();
          },
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack, // aproxima el spring de SwiftUI
            child: Container(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Insets.cardLg),
              decoration: widget.decoration,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// `MCPrimaryButton` — CTA primario full-width Midnight Sage.
///
/// Portado del `MCPrimaryButton` ButtonStyle del iOS: full-width, `minHeight 54`,
/// fill `brandPrimary` (sage glow), texto `#0E1312`, esquinas continuous
/// (`Radii.button` = 20), scale 0.97 al apretar.
class MCPrimaryButton extends StatelessWidget {
  const MCPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// Texto del botón.
  final String label;

  /// Callback. Si es null, el botón se ve disabled (atenuado, sin press).
  final VoidCallback? onPressed;

  /// Icono opcional a la izquierda del label.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity, // full-width como el `.frame(maxWidth: .infinity)`
      child: _MCButtonBase(
        onPressed: onPressed,
        minHeight: 54,
        label: label,
        icon: icon,
        textStyle: _primaryLabelStyle(_kOnPrimary),
        decoration: ShapeDecoration(
          color: colors.brandPrimary,
          shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.button)),
        ),
      ),
    );
  }
}

/// `MCSecondaryButton` — acción secundaria full-width.
///
/// Portado del `MCSecondaryButton` del iOS: fill `white @ 0.05` sobre surface,
/// stroke `appBorder` de 1pt, texto `textPrimary`, `minHeight 52`, esquinas
/// continuous (el iOS usa radio 18 = `Radii.card`), scale 0.97.
class MCSecondaryButton extends StatelessWidget {
  const MCSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// Texto del botón.
  final String label;

  /// Callback. Si es null, el botón se ve disabled (atenuado, sin press).
  final VoidCallback? onPressed;

  /// Icono opcional a la izquierda del label.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      child: _MCButtonBase(
        onPressed: onPressed,
        minHeight: 52,
        label: label,
        icon: icon,
        // iOS: `Font.system(size: 14, weight: .bold)` → Inter w700 (AppText.h2)
        // bajado a 14pt.
        textStyle: AppText.h2(colors.textPrimary).copyWith(fontSize: 14),
        decoration: ShapeDecoration(
          // Fill `white @ 0.05` literal del iOS: overlay translúcido sutil que
          // deja ver el fondo (el secundario suele ir sobre `appBackground`, no
          // dentro de una card). El borde `appBorder` carga la forma.
          color: Colors.white.withValues(alpha: 0.05),
          shape: SmoothRectangleBorder(
            borderRadius: Radii.smooth(Radii.card),
            side: BorderSide(color: colors.appBorder, width: 1),
          ),
        ),
      ),
    );
  }
}

/// El iOS usa `Font.system(size: 15, weight: .semibold)` para el primario.
/// Reusamos Inter w600 vía AppText para mantener la familia consistente.
TextStyle _primaryLabelStyle(Color c) =>
    AppText.body(c).copyWith(fontSize: 15, fontWeight: FontWeight.w600);
