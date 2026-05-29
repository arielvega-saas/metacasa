import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';

/// Una entrada del menú "Más".
class _MoreItem {
  const _MoreItem(this.icon, this.label, {this.route});
  final IconData icon;
  final String label;

  /// Ruta a pushear (null = placeholder, destino en olas futuras).
  final String? route;
}

/// Tab "Más" — espejo de `MoreView` (iOS): agrupador de pantallas secundarias.
/// Por ahora las filas son placeholders (no navegan); cada destino se porta en
/// olas futuras. El orden/agrupado sigue al iOS (organización · hogar · premium).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _organization = <_MoreItem>[
    _MoreItem(LucideIcons.wallet, 'Cuentas', route: '/more/accounts'),
    _MoreItem(LucideIcons.target, 'Metas', route: '/more/goals'),
    _MoreItem(LucideIcons.repeat, 'Recurrentes', route: '/more/recurring'),
    _MoreItem(LucideIcons.calendarClock, 'Vencimientos', route: '/more/bills'),
    _MoreItem(LucideIcons.creditCard, 'Cuotas', route: '/more/installments'),
    _MoreItem(LucideIcons.arrowDownToLine, 'Deudas', route: '/more/debts'),
    _MoreItem(LucideIcons.barChart3, 'Reportes', route: '/more/reports'),
  ];

  static const _household = <_MoreItem>[
    _MoreItem(LucideIcons.home, 'Hogar', route: '/more/household'),
    _MoreItem(LucideIcons.settings, 'Ajustes', route: '/more/settings'),
  ];

  static const _premium = <_MoreItem>[
    _MoreItem(LucideIcons.crown, 'Premium'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title: Text('Más', style: AppText.serifInline(c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.md,
          Insets.screen,
          Insets.xxl,
        ),
        children: const [
          _Section(title: 'Organización', items: _organization),
          SizedBox(height: Insets.section),
          _Section(title: 'Hogar', items: _household),
          SizedBox(height: Insets.section),
          _Section(title: 'Premium', items: _premium),
        ],
      ),
    );
  }
}

/// Grupo de filas dentro de una card squircle con hairline sage, al estilo de
/// las `List`/`Section` insetGrouped del iOS.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<_MoreItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.md),
          child: Text(title.toUpperCase(), style: AppText.label(c.textMuted)),
        ),
        // ClipPath con la misma SmoothRectangleBorder: el ripple del InkWell
        // respeta la esquina continuous (squircle) de la card. El borde hairline
        // lo pinta el ShapeDecoration de adentro.
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
                for (var i = 0; i < items.length; i++) ...[
                  _Row(item: items[i]),
                  if (i != items.length - 1)
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
      ],
    );
  }
}

/// Fila individual del menú. Placeholder: el tap no navega todavía (TODO portar
/// destinos). Se deja un chevron para señalar que será navegable.
class _Row extends StatelessWidget {
  const _Row({required this.item});
  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      // Navega si el item tiene ruta; si no, placeholder (destino en olas futuras).
      onTap: item.route == null ? () {} : () => context.push(item.route!),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.cardLg,
          vertical: Insets.card,
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: c.brandPrimary),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Text(item.label, style: AppText.body(c.textPrimary)),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textDim),
          ],
        ),
      ),
    );
  }
}
