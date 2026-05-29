import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';

/// Texto oscuro sobre el sage del chip seleccionado — clavado en iOS (`#0E1312`).
const Color _kSelectedText = Color(0xFF0E1312);

/// `MCChip` — pill seleccionable Midnight Sage.
///
/// Portado 1:1 del `MCChip` del iOS (`Core/Interactions.swift`). Es un control
/// *stateless* (el `selected` lo gobierna el caller, igual que el iOS), pensado
/// para filtros, sugerencias rápidas y selección de categorías.
///
/// Anatomía:
/// - Seleccionado: fill `brandPrimary` (sage), texto `#0E1312`, scale 1.05,
///   border `brandPrimary` 1.5pt.
/// - Sin seleccionar: fill `appSurface`, texto `textPrimary`, border `appBorder`
///   1pt.
/// - Capsule / `StadiumBorder`.
/// - Cambio de estado animado con spring (response 0.32 / damping 0.68 del iOS).
/// - Tap → selection haptic automático.
///
/// `icon` acepta tanto un emoji (vía [emoji]) como un [IconData] de lucide; usar
/// el que corresponda al call-site.
class MCChip extends StatelessWidget {
  const MCChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.emoji,
  });

  /// Texto del chip.
  final String label;

  /// Estado de selección (controlado por el caller).
  final bool selected;

  /// Callback de tap. Dispara selection haptic antes de invocarse.
  final VoidCallback onTap;

  /// Icono lucide opcional a la izquierda del label.
  final IconData? icon;

  /// Emoji opcional a la izquierda (equivalente al `icon: String?` del iOS).
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = selected ? _kSelectedText : colors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      // Spring de selección: la escala 1.05↔1 se anima con un curve elástico que
      // aproxima el `.spring(response: 0.32, dampingFraction: 0.68)` del iOS.
      child: AnimatedScale(
        scale: selected ? 1.05 : 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.card, // H14 del iOS
            vertical: Insets.lg, // V10 del iOS
          ),
          decoration: ShapeDecoration(
            color: selected ? colors.brandPrimary : colors.appSurface,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? colors.brandPrimary : colors.appBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: AppText.caption(fg)),
                const SizedBox(width: Insets.sm),
              ] else if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: Insets.sm),
              ],
              Text(
                label,
                // iOS: `.mcCaption.weight(.semibold)`.
                style: AppText.caption(fg).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
