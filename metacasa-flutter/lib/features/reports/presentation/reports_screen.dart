import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/reports_controller.dart';
import 'annual_screen.dart';
import 'compare_months_screen.dart';
import 'report_palette.dart';
import 'spending_heatmap_screen.dart';

/// Pantalla de Reportes / Estadísticas — espejo de `ReportsView` (iOS), con
/// gráficos `fl_chart` (Midnight Sage) en lugar de Swift Charts.
///
/// Estructura (de arriba a abajo):
///   1. Health score: anillo 0–100 (PieChart) + banda/color + tasa de ahorro.
///   2. 6 meses: barras agrupadas ingreso vs gasto (`BarChart`).
///   3. Pareto 80/20: donut top 8 categorías (`PieChart` con centerSpaceRadius)
///      + leyenda con % y montos.
///   4. Breakdown de categorías: lista completa con barra de share.
///   5. Atajos: Vista anual · Comparar meses · Mapa de gasto (push interno).
///
/// Montos privacy-aware (modo ojo). Pull-to-refresh recomputa el controller.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final bool privacy = ref.watch(privacyModeProvider);

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Reportes', style: AppText.h2(c.textPrimary)),
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () => ref.read(reportsControllerProvider.notifier).refresh(),
        child: _ReportsBody(privacy: privacy),
      ),
    );
  }
}

/// Cuerpo: resuelve loading / error / data del [reportsControllerProvider].
class _ReportsBody extends ConsumerWidget {
  const _ReportsBody({required this.privacy});

  final bool privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReportsState> async = ref.watch(reportsControllerProvider);
    final String currency =
        ref.watch(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
            'USD';

    return async.when(
      loading: () => const _ReportsSkeleton(),
      error: (Object err, StackTrace _) => _ErrorState(
        onRetry: () => ref.read(reportsControllerProvider.notifier).refresh(),
      ),
      data: (ReportsState state) => _ReportsContent(
        state: state,
        currency: currency,
        privacy: privacy,
      ),
    );
  }
}

/// Contenido con datos. Siempre scrollable (pull-to-refresh) y SIEMPRE muestra
/// los atajos a Anual/Comparar/Heatmap, aunque no haya movimientos.
class _ReportsContent extends StatelessWidget {
  const _ReportsContent({
    required this.state,
    required this.currency,
    required this.privacy,
  });

  final ReportsState state;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120, // espacio para el FAB del asistente del shell
      ),
      children: [
        _HealthScoreCard(
          score: state.healthScore,
          band: state.band,
          savingsRate: state.savingsRate,
        ),
        const SizedBox(height: Insets.section),
        _SixMonthsCard(months: state.sixMonths, currency: currency),
        const SizedBox(height: Insets.section),
        _ParetoCard(
          slices: state.pareto,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        _CategoryBreakdownCard(
          slices: state.pareto,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        const _ReportsLinksCard(),
      ],
    );
  }
}

// ─────────────────────────────── Health score ──────────────────────────────

/// Card del health score: anillo 0–100 (PieChart con centerSpaceRadius) con el
/// número grande en serif al centro, badge de banda y subtítulo con la tasa de
/// ahorro. Color por banda (espejo del `healthScoreCard` de iOS).
class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({
    required this.score,
    required this.band,
    required this.savingsRate,
  });

  final int score;
  final HealthBand band;
  final double savingsRate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color color = _bandColor(c, band);
    final double pct = (score / 100).clamp(0.0, 1.0);

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.heartPulse, size: 16, color: color),
              const SizedBox(width: Insets.md),
              Expanded(
                child:
                    Text('SALUD FINANCIERA', style: AppText.label(c.textMuted)),
              ),
              _BandBadge(label: band.label, color: color),
            ],
          ),
          const SizedBox(height: Insets.cardLg),
          Row(
            children: [
              // Anillo 0–100 con el número al centro.
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 0,
                        centerSpaceRadius: 44,
                        sections: <PieChartSectionData>[
                          PieChartSectionData(
                            value: pct == 0 ? 0.0001 : pct,
                            color: color,
                            radius: 12,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: (1 - pct).clamp(0.0001, 1.0),
                            color: c.appSurfaceInset,
                            radius: 12,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: AppText.serifDisplay(color),
                        ),
                        Text('/ 100', style: AppText.caption(c.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.cardLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headline(band),
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      _subtitle(savingsRate),
                      style: AppText.caption(c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _bandColor(MidnightSageColors c, HealthBand band) =>
      switch (band) {
        HealthBand.excellent => c.brandSuccess,
        HealthBand.good => c.brandPrimary,
        HealthBand.fair => c.brandWarning,
        HealthBand.poor => c.brandDanger,
      };

  static String _headline(HealthBand band) => switch (band) {
        HealthBand.excellent => 'Tus finanzas están en gran forma',
        HealthBand.good => 'Vas por buen camino',
        HealthBand.fair => 'Hay margen para mejorar',
        HealthBand.poor => 'Conviene apretar el cinturón',
      };

  /// Subtítulo con la tasa de ahorro del semestre (no expone montos → no es
  /// sensible al modo privacidad).
  static String _subtitle(double savingsRate) {
    final int pct = (savingsRate * 100).round();
    return 'Ahorrás el $pct% de lo que ingresás (últimos 6 meses).';
  }
}

/// Badge de banda: pill con color de la banda al 20%.
class _BandBadge extends StatelessWidget {
  const _BandBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 4),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.2),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: AppText.caption(color).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─────────────────────────────── 6-month bars ──────────────────────────────

/// Card de la serie de 6 meses: barras agrupadas ingreso (sage) vs gasto
/// (coral). Espejo del `sixMonthsCard` de iOS. Los ejes muestran el label del
/// mes (X) y montos abreviados (Y). Sin tooltips (no interactivo) para
/// mantenerlo simple y robusto.
class _SixMonthsCard extends StatelessWidget {
  const _SixMonthsCard({required this.months, required this.currency});

  final List<MonthlySummary> months;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Tope del eje Y (con 12% de aire arriba). Si todo es 0, eje 0..1.
    double maxVal = 0;
    for (final MonthlySummary m in months) {
      final double ing = m.ingresos.toDouble();
      final double gas = m.gastos.toDouble();
      if (ing > maxVal) maxVal = ing;
      if (gas > maxVal) maxVal = gas;
    }
    final double maxY = maxVal <= 0 ? 1 : maxVal * 1.12;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart3, size: 16, color: c.textMuted),
              const SizedBox(width: Insets.md),
              Text('ÚLTIMOS 6 MESES', style: AppText.label(c.textMuted)),
            ],
          ),
          const SizedBox(height: Insets.cardLg),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (double _) =>
                      FlLine(color: c.appBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY / 2,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            Money.format(
                              Decimal.parse(value.toStringAsFixed(0)),
                              currencyCode: currency,
                              style: MoneyStyle.abbreviated,
                              locale: 'es_AR',
                            ),
                            style: AppText.caption(c.textDim)
                                .copyWith(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            months[i].label,
                            style: AppText.caption(c.textMuted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < months.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 3,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: months[i].ingresos.toDouble(),
                          color: c.brandSuccess,
                          width: 9,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                        BarChartRodData(
                          toY: months[i].gastos.toDouble(),
                          color: c.brandDanger,
                          width: 9,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.card),
          Row(
            children: [
              _LegendDot(color: c.brandSuccess, label: 'Ingresos'),
              const SizedBox(width: Insets.xl),
              _LegendDot(color: c.brandDanger, label: 'Gastos'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Punto de leyenda: círculo de color + etiqueta.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: Insets.sm),
        Text(label, style: AppText.caption(c.textMuted)),
      ],
    );
  }
}

// ─────────────────────────────── Pareto donut ──────────────────────────────

/// Card del Pareto 80/20: donut (PieChart con centerSpaceRadius) de las top 8
/// categorías de gasto del mes + leyenda con emoji, %, y monto. Espejo del
/// `paretoCard` de iOS. Empty-state si no hay gastos este mes.
class _ParetoCard extends StatelessWidget {
  const _ParetoCard({
    required this.slices,
    required this.currency,
    required this.privacy,
  });

  final List<CategorySlice> slices;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final List<CategorySlice> top = slices.take(8).toList();

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.percent, size: 16, color: c.textMuted),
              const SizedBox(width: Insets.md),
              Text('REGLA 80/20 · ESTE MES', style: AppText.label(c.textMuted)),
            ],
          ),
          const SizedBox(height: Insets.cardLg),
          if (top.isEmpty)
            _InlineEmpty(
              icon: LucideIcons.pieChart,
              message: 'Todavía no cargaste gastos este mes.',
            )
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: <PieChartSectionData>[
                    for (int i = 0; i < top.length; i++)
                      PieChartSectionData(
                        value: top[i].percent,
                        color: ReportPalette.categoryColor(c, i),
                        radius: 28,
                        title: top[i].percent >= 0.08
                            ? '${(top[i].percent * 100).round()}%'
                            : '',
                        titleStyle: AppText.caption(c.appBackground)
                            .copyWith(fontWeight: FontWeight.w700),
                        titlePositionPercentageOffset: 0.6,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Insets.cardLg),
            // Leyenda: una fila por categoría top.
            for (int i = 0; i < top.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ReportPalette.categoryColor(c, i),
                      ),
                    ),
                    const SizedBox(width: Insets.lg),
                    Text(CategoryCatalog.emojiFor(top[i].category),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        top[i].category,
                        style: AppText.body(c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Text(
                      '${(top[i].percent * 100).round()}%',
                      style: AppText.caption(c.textMuted)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: Insets.lg),
                    AmountText(
                      value: top[i].amount,
                      currencyCode: currency,
                      kind: AmountKind.gasto,
                      obscured: privacy,
                      moneyStyle: MoneyStyle.compact,
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Category breakdown ────────────────────────────

/// Breakdown completo de categorías del mes: nombre, monto y barra de share.
/// Espejo del `categoryBreakdownCard` de iOS. Reusa todo el Pareto (no solo el
/// top 8). Empty-state si no hay gastos.
class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.slices,
    required this.currency,
    required this.privacy,
  });

  final List<CategorySlice> slices;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MCSectionHeader(title: 'Por categoría'),
          const SizedBox(height: Insets.card),
          if (slices.isEmpty)
            _InlineEmpty(
              icon: LucideIcons.tag,
              message: 'Sin gastos para desglosar este mes.',
            )
          else
            for (final CategorySlice s in slices)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(CategoryCatalog.emojiFor(s.category),
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            s.category,
                            style: AppText.body(c.textPrimary)
                                .copyWith(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        AmountText(
                          value: s.amount,
                          currencyCode: currency,
                          kind: AmountKind.gasto,
                          obscured: privacy,
                          moneyStyle: MoneyStyle.compact,
                          style: AppText.body(c.textPrimary)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    MCProgressBar(
                      percent: s.percent.clamp(0.0, 1.0),
                      height: 6,
                      color: c.brandDanger,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Atajos ────────────────────────────────────

/// Card de atajos a las sub-pantallas de reportes (push interno con
/// MaterialPageRoute, mismo patrón que el resto de las features Flutter).
class _ReportsLinksCard extends StatelessWidget {
  const _ReportsLinksCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Column(
        children: [
          _LinkRow(
            icon: LucideIcons.calendarRange,
            label: 'Vista anual',
            subtitle: 'Los 12 meses del año, mes a mes',
            onTap: () => _push(context, const AnnualScreen()),
          ),
          Divider(color: c.appBorder, height: 1, indent: 52),
          _LinkRow(
            icon: LucideIcons.gitCompare,
            label: 'Comparar meses',
            subtitle: 'Dos meses lado a lado, con su diferencia',
            onTap: () => _push(context, const CompareMonthsScreen()),
          ),
          Divider(color: c.appBorder, height: 1, indent: 52),
          _LinkRow(
            icon: LucideIcons.calendarDays,
            label: 'Mapa de gasto',
            subtitle: 'Tu año día por día, estilo calendario de calor',
            onTap: () => _push(context, const SpendingHeatmapScreen()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

/// Fila de atajo: ícono en círculo sage + título/subtítulo + chevron.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.card,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.brandPrimary.withValues(alpha: 0.15),
              ),
              child: Icon(icon, size: 18, color: c.brandPrimary),
            ),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.body(c.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    subtitle,
                    style: AppText.caption(c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textDim),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Shared bits ───────────────────────────────

/// Empty-state inline (dentro de una card): ícono tenue + mensaje.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Text(message, style: AppText.caption(c.textMuted)),
          ),
        ],
      ),
    );
  }
}

/// Estado de error: EmptyState con reintento. Scrollable para el pull-to-refresh.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.cloudOff,
            title: 'No pudimos cargar tus reportes',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Skeleton mientras carga: bloques con el shape de las cards. Scrollable.
class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120,
      ),
      children: const [
        _SkeletonBlock(height: 150), // health
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 250), // 6 meses
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 320), // pareto
      ],
    );
  }
}

/// Bloque rectangular de skeleton (superficie con esquinas squircle).
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      decoration: ShapeDecoration(
        color: c.appSurface,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      ),
    );
  }
}
