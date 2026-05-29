import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';

/// `MCSectionHeader` — encabezado de sección Midnight Sage.
///
/// Título `AppText.h2` a la izquierda + acción trailing opcional. Replica el
/// patrón "HStack { Text(title); Spacer(); Button(...) }" que el iOS repite a
/// mano en las pantallas de feature (Home, Reports, etc.).
///
/// Hay tres formas de dar la acción trailing (en orden de preferencia):
/// 1. [trailing] — un widget arbitrario (máxima flexibilidad).
/// 2. [actionLabel] + [onAction] — link de texto (sage) con selection haptic.
/// 3. nada — solo el título.
class MCSectionHeader extends StatelessWidget {
  const MCSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  /// Texto del encabezado.
  final String title;

  /// Widget trailing arbitrario (pisa [actionLabel]/[onAction] si se provee).
  final Widget? trailing;

  /// Texto del link de acción opcional. Requiere [onAction].
  final String? actionLabel;

  /// Callback del link de acción opcional. Requiere [actionLabel].
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final Widget? trailingWidget = trailing ??
        ((actionLabel != null && onAction != null)
            ? _ActionLink(
                label: actionLabel!,
                color: colors.brandPrimary,
                onTap: onAction!,
              )
            : null);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.h2(colors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingWidget != null) ...[
          const SizedBox(width: Insets.xl),
          trailingWidget,
        ],
      ],
    );
  }
}

/// Link de texto trailing — sage, semibold, con selection haptic. Privado:
/// expuesto solo vía `MCSectionHeader(actionLabel:, onAction:)`.
class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      // Tap target accesible: el texto es chico (<44dp), así que garantizamos
      // un alto mínimo de 44dp + padding horizontal sin alterar el visual.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style:
                  AppText.caption(color).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
