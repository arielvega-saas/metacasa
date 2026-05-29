import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../state/settings_providers.dart';

/// Picker de tema (Claro / Oscuro / Automático) — espejo de
/// `AppearanceSettingsView` de iOS. Cumplir las guías de plataforma requiere
/// ofrecer "seguir el sistema"; el default histórico de la app es Oscuro.
///
/// Muta [appearanceModeProvider] (persiste en `shared_preferences`); el cambio
/// se refleja al instante en toda la app porque `MaterialApp` lo observa.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ThemeMode current = ref.watch(appearanceModeProvider);

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title: Text('Apariencia', style: AppText.h2(c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.md,
          Insets.screen,
          Insets.xxl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.md),
            child: Text('TEMA', style: AppText.label(c.textMuted)),
          ),
          _OptionsCard(
            options: const [
              (ThemeMode.light, 'Claro', LucideIcons.sun),
              (ThemeMode.dark, 'Oscuro', LucideIcons.moon),
              (ThemeMode.system, 'Automático', LucideIcons.smartphone),
            ],
            current: current,
            onSelected: (ThemeMode mode) {
              HapticFeedback.selectionClick();
              ref.read(appearanceModeProvider.notifier).set(mode);
            },
          ),
          const SizedBox(height: Insets.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
            child: Text(
              'Automático sigue el tema del sistema. La app está pensada para el '
              'modo oscuro.',
              style: AppText.caption(c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card squircle con las opciones de tema como filas radio (ícono + label +
/// check). Mismo look insetGrouped que `more_screen.dart`.
class _OptionsCard extends StatelessWidget {
  const _OptionsCard({
    required this.options,
    required this.current,
    required this.onSelected,
  });

  final List<(ThemeMode, String, IconData)> options;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: c.appSurface,
          shape: SmoothRectangleBorder(
            borderRadius: Radii.smooth(Radii.card),
            side: BorderSide(color: c.appBorder, width: 1),
          ),
        ),
        child: Column(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              _OptionRow(
                label: options[i].$2,
                icon: options[i].$3,
                selected: options[i].$1 == current,
                onTap: () => onSelected(options[i].$1),
              ),
              if (i != options.length - 1)
                Divider(
                  color: c.appBorder,
                  height: 1,
                  thickness: 1,
                  indent: Insets.cardLg,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.cardLg,
          vertical: Insets.card,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.brandPrimary),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Text(label, style: AppText.body(c.textPrimary)),
            ),
            if (selected)
              Icon(LucideIcons.check, size: 18, color: c.brandPrimary),
          ],
        ),
      ),
    );
  }
}
