import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// `MCCard` — el contenedor canónico de Midnight Sage.
///
/// Portado 1:1 del modifier `MCCard` del iOS (`Core/DesignSystem.swift`): fill
/// `appSurface`, hairline `appBorder` de 1pt y esquinas continuous (squircle).
///
/// Diferencias deliberadas vs iOS:
/// - El iOS clava radio 24 inline; acá usamos `Radii.card` (18) por decisión de
///   tokens del equipo Flutter (el squircle de figma_squircle ya se lee más
///   redondeado que un `RoundedRectangle` Material al mismo radio).
/// - Padding default `Insets.cardLg` (20) = el H20/V16 del iOS unificado a 20.
///
/// Variante `glow`: replica `glowIfPositive` (iOS `Core/Interactions.swift`) —
/// stroke `brandPrimary @ 0.45` de 1pt + un bloom de color (`brandPrimary @ 0.25`,
/// blur 12, sin spread), para resaltar cards "positivas" (dentro de budget, foco).
///
/// `onTap`: si se provee, la card se vuelve pressable con scale ~0.97 (spring,
/// igual que `PressableScale` del iOS) y dispara `HapticFeedback.selectionClick`.
class MCCard extends StatefulWidget {
  const MCCard({
    super.key,
    required this.child,
    this.padding,
    this.glow = false,
    this.onTap,
  });

  /// Contenido de la card.
  final Widget child;

  /// Padding interno. Default `EdgeInsets.all(Insets.cardLg)` (20).
  final EdgeInsetsGeometry? padding;

  /// Si true, pinta borde sage + glow sutil (resalta valores positivos).
  final bool glow;

  /// Callback de tap. Si es null, la card no es interactiva (sin scale/haptic).
  final VoidCallback? onTap;

  @override
  State<MCCard> createState() => _MCCardState();
}

class _MCCardState extends State<MCCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = Radii.smooth(Radii.card);

    // Borde y sombra cambian según la variante glow. Recipe portada 1:1 de
    // `glowIfPositive` (iOS): stroke sage @ 0.45 + bloom de color sage @ 0.25
    // (blur 12, spread 0, sin offset). El no-glow queda en hairline `appBorder`.
    final borderColor = widget.glow
        ? colors.brandPrimary.withValues(alpha: 0.45)
        : colors.appBorder;
    final shadows = widget.glow
        ? [
            BoxShadow(
              color: colors.brandPrimary.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ]
        : null;

    final card = AnimatedContainer(
      // El scale lo maneja el AnimatedScale externo; acá animamos solo color.
      duration: const Duration(milliseconds: 150),
      padding: widget.padding ?? const EdgeInsets.all(Insets.cardLg),
      decoration: ShapeDecoration(
        color: colors.appSurface,
        shape: SmoothRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor, width: 1),
        ),
        shadows: shadows,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return card;

    // Pressable: scale 0.97 con spring (response 0.28 / damping 0.62 del iOS) +
    // selection haptic al apretar. GestureDetector con HitTestBehavior.opaque
    // para captar taps sobre el padding/áreas vacías de la card.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _setPressed(true);
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack, // aproxima el spring de SwiftUI
        child: card,
      ),
    );
  }
}
