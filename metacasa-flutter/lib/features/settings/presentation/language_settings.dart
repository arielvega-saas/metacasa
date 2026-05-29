import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../state/settings_providers.dart';

/// Una opción de idioma de la lista. `locale == null` → seguir el sistema.
typedef _LangOption = ({Locale? locale, String flag, String label});

/// Picker de idioma (Sistema / Español / English / Português) — espejo de
/// `LanguageSettingsView` de iOS.
///
/// Muta [localeOverrideProvider] (persiste en `shared_preferences`): `null`
/// vuelve a seguir el device, un `Locale` fuerza el idioma. El cambio re-pinta
/// la app al instante (lo observa `MaterialApp.locale`).
///
/// El catálogo se acota a los `supportedLocales` de la app (es · en · pt), sin
/// variante regional: el formateo de montos por país lo resuelve `AmountText`
/// a partir del locale efectivo del device.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  static const List<_LangOption> _options = <_LangOption>[
    (locale: null, flag: '🌐', label: 'Predeterminado del sistema'),
    (locale: Locale('es'), flag: '🇪🇸', label: 'Español'),
    (locale: Locale('en'), flag: '🇺🇸', label: 'English'),
    (locale: Locale('pt'), flag: '🇧🇷', label: 'Português'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final Locale? current = ref.watch(localeOverrideProvider);

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title: Text('Idioma', style: AppText.h2(c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.md,
          Insets.screen,
          Insets.xxl,
        ),
        children: [
          ClipPath(
            clipper: ShapeBorderClipper(
              shape: SmoothRectangleBorder(
                borderRadius: Radii.smooth(Radii.card),
              ),
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
                  for (var i = 0; i < _options.length; i++) ...[
                    _LangRow(
                      option: _options[i],
                      selected: _options[i].locale?.languageCode ==
                          current?.languageCode,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(localeOverrideProvider.notifier)
                            .set(_options[i].locale);
                      },
                    ),
                    if (i != _options.length - 1)
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
          ),
          const SizedBox(height: Insets.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
            child: Text(
              'El idioma afecta los textos de la app. El formato de los montos '
              'sigue tu región.',
              style: AppText.caption(c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _LangOption option;
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
            Text(option.flag, style: AppText.h2(c.textPrimary)),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Text(option.label, style: AppText.body(c.textPrimary)),
            ),
            if (selected)
              Icon(LucideIcons.check, size: 18, color: c.brandPrimary),
          ],
        ),
      ),
    );
  }
}
