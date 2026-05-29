import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import 'mc_button.dart';

/// `EmptyState` — estado vacío centrado Midnight Sage.
///
/// Cubre dos looks con un solo widget:
/// 1. **Con icono** (default): equivalente del `ContentUnavailableView` del iOS
///    (Goals, Debts, Bills, Accounts) — icono lucide grande tenue + título +
///    mensaje, con CTA opcional.
/// 2. **Eyebrow + serif** ([eyebrow] + [serifTitle]): el look "Próximamente" de
///    las pantallas placeholder — overline smallCaps sage sobre un título serif,
///    sin icono. (Reemplaza al ex `ComingSoonBody`.)
///
/// Anatomía:
/// - [eyebrow] opcional: `AppText.label` (sage) arriba del título.
/// - [icon] opcional: lucide ~48, color `textMuted`.
/// - Título: `AppText.serifTitle` si [serifTitle] es true, si no `AppText.h2`.
/// - [message] opcional: `AppText.body` (`textMuted`), centrado.
/// - CTA opcional: pill secundario ([MCSecondaryButton]) cuando se pasan
///   [actionLabel] + [onAction]. Se restringe el ancho para que no ocupe toda
///   la pantalla (el secundario es full-width por default).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    this.eyebrow,
    this.serifTitle = false,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Icono lucide representativo del vacío (ej. `LucideIcons.target`). Opcional:
  /// el look "eyebrow + serif" va sin icono.
  final IconData? icon;

  /// Título corto del estado vacío.
  final String title;

  /// Overline opcional en smallCaps sage (ej. "PORTADA"), arriba del título.
  final String? eyebrow;

  /// Si true, el título usa `AppText.serifTitle` (editorial); si no, `AppText.h2`.
  final bool serifTitle;

  /// Mensaje/hint opcional debajo del título.
  final String? message;

  /// Texto del CTA opcional. Requiere [onAction] para renderizarse.
  final String? actionLabel;

  /// Callback del CTA opcional. Requiere [actionLabel] para renderizarse.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasCta = actionLabel != null && onAction != null;
    final titleStyle = serifTitle
        ? AppText.serifTitle(colors.textPrimary)
        : AppText.h2(colors.textPrimary);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (eyebrow != null) ...[
              Text(eyebrow!, style: AppText.label(colors.brandPrimary)),
              const SizedBox(height: Insets.md),
            ],
            if (icon != null) ...[
              Icon(icon, size: 48, color: colors.textMuted),
              const SizedBox(height: Insets.section),
            ],
            Text(
              title,
              style: titleStyle,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                message!,
                style: AppText.body(colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (hasCta) ...[
              const SizedBox(height: Insets.xxl),
              // Acotamos el ancho: el secundario es full-width, pero un CTA de
              // empty-state se ve mejor compacto y centrado.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: MCSecondaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
