import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// `MCProgressBar` — barra de progreso de presupuesto (envelope) Midnight Sage.
///
/// Track `appSurfaceInset` + fill de color automático según el % usado vía
/// `colors.budgetThreshold(percent)` (>0.95 coral, >0.80 champagne, si no sage).
/// Replica el patrón inline del iOS (track inset + Capsule de color sobre
/// GeometryReader). Esquinas redondeadas (`Radii.progress` = 8) y ancho del fill
/// animado (`AnimatedFractionallySizedBox`).
///
/// `percent` se clampa a [0, 1] para el ancho visual, pero el color usa el valor
/// crudo (un overspending de 1.2 igual cae en coral, correcto).
class MCProgressBar extends StatelessWidget {
  const MCProgressBar({
    super.key,
    required this.percent,
    this.height = 10,
    this.color,
    this.trackColor,
    this.duration = const Duration(milliseconds: 450),
  });

  /// Fracción usada del presupuesto. 0 = vacío, 1 = lleno. >1 = overspending
  /// (el ancho se clampa a 1, pero el color refleja el exceso).
  final double percent;

  /// Alto de la barra. Default 10 (igual que el iOS).
  final double height;

  /// Override del color del fill. Si es null, se deriva de `budgetThreshold`.
  final Color? color;

  /// Override del color del track. Si es null, usa `appSurfaceInset`.
  final Color? trackColor;

  /// Duración de la animación de ancho del fill.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // El ancho se clampa; el color usa el % crudo (overspending → coral).
    final clamped = percent.clamp(0.0, 1.0);
    final fillColor = color ?? colors.budgetThreshold(percent);
    final radius = Radii.smooth(Radii.progress);

    return ClipSmoothRect(
      radius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            // Track de fondo.
            DecoratedBox(
              decoration: BoxDecoration(
                color: trackColor ?? colors.appSurfaceInset,
              ),
              child: const SizedBox.expand(),
            ),
            // Fill animado: el ancho crece/decrece con un ease suave.
            AnimatedFractionallySizedBox(
              duration: duration,
              curve: Curves.easeOut,
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: fillColor,
                  shape: SmoothRectangleBorder(borderRadius: radius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
