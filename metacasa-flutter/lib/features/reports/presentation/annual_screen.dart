import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/finance/balance_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';

/// Totales de un mes del año (1–12). Espejo de `MonthTotals` (iOS `AnnualView`).
class _MonthTotals {
  const _MonthTotals({
    required this.month,
    required this.ingresos,
    required this.gastos,
  });

  final int month;
  final Decimal ingresos;
  final Decimal gastos;

  Decimal get balance => ingresos - gastos;
}

/// Vista anual — espejo de `AnnualView` (iOS). Pantalla auto-contenida con su
/// propio estado (año seleccionado + datos cargados), igual que el `@State` del
/// SwiftUI. Pushada desde Reportes con `Navigator.push`.
///
/// Estructura:
///   1. Picker de año (‹ Año ›, tope = año actual + 5).
///   2. Totales anuales (ingresos / gastos / balance).
///   3. BarChart de los 12 meses (ingreso vs gasto agrupados).
///   4. Grilla 2-col con el detalle por mes.
class AnnualScreen extends ConsumerStatefulWidget {
  const AnnualScreen({super.key});

  @override
  ConsumerState<AnnualScreen> createState() => _AnnualScreenState();
}

class _AnnualScreenState extends ConsumerState<AnnualScreen> {
  late int _year;
  List<_MonthTotals> _monthly = const <_MonthTotals>[];
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  /// Trae los movimientos del año completo (`fetchRange`) y los agrupa por mes.
  /// Espejo del `reload()` de iOS (mismo rango año-completo, mismo group-by).
  Future<void> _reload() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (!mounted) return;
    if (householdId == null) {
      setState(() {
        _monthly = const <_MonthTotals>[];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final DateTime from = DateTime(_year, 1, 1);
      final DateTime to = DateTime(_year, 12, 31, 23, 59, 59);
      final List<Transaction> txs =
          await ref.read(transactionRepositoryProvider).fetchRange(
                householdId: householdId,
                from: from,
                to: to,
                limit: 50000,
              );
      if (!mounted) return;
      final List<_MonthTotals> monthly =
          List<_MonthTotals>.generate(12, (int i) {
        final int m = i + 1;
        var ing = Decimal.zero;
        var gas = Decimal.zero;
        for (final Transaction tx in txs.excludingTransfers) {
          if (tx.date.month != m) continue;
          switch (tx.type) {
            case TxType.ingreso:
              ing += tx.amountInBase;
            case TxType.gasto:
              gas += tx.amountInBase;
          }
        }
        return _MonthTotals(month: m, ingresos: ing, gastos: gas);
      });
      setState(() {
        _monthly = monthly;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _changeYear(int delta) {
    final int maxYear = DateTime.now().year + 5;
    final int next = _year + delta;
    if (next < 2000 || next > maxYear) return;
    HapticFeedback.selectionClick();
    setState(() => _year = next);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool privacy = ref.watch(privacyModeProvider);
    final String currency =
        ref.watch(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
            'USD';

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Vista anual', style: AppText.h2(c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.md,
          Insets.screen,
          Insets.xxl,
        ),
        children: [
          _YearPicker(year: _year, onChange: _changeYear),
          const SizedBox(height: Insets.section),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _InlineError(onRetry: _reload)
          else ...[
            _AnnualTotalsCard(
              monthly: _monthly,
              currency: currency,
              privacy: privacy,
            ),
            const SizedBox(height: Insets.section),
            _AnnualChartCard(
              monthly: _monthly,
              currency: currency,
            ),
            const SizedBox(height: Insets.section),
            _MonthsGrid(
              monthly: _monthly,
              currency: currency,
              privacy: privacy,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Year picker ───────────────────────────────

/// Picker ‹ Año › con flechas. Espejo del `yearPickerCard` de iOS.
class _YearPicker extends StatelessWidget {
  const _YearPicker({required this.year, required this.onChange});

  final int year;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.chevronLeft, color: c.brandPrimary),
            tooltip: 'Año anterior',
            onPressed: () => onChange(-1),
          ),
          Expanded(
            child: Text(
              '$year',
              textAlign: TextAlign.center,
              style: AppText.serifTitle(c.textPrimary),
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.chevronRight, color: c.brandPrimary),
            tooltip: 'Año siguiente',
            onPressed: () => onChange(1),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Totales ───────────────────────────────────

/// Totales anuales: ingresos + gastos (lado a lado) + balance (ancho completo).
/// Espejo del `annualTotalsCard` de iOS.
class _AnnualTotalsCard extends StatelessWidget {
  const _AnnualTotalsCard({
    required this.monthly,
    required this.currency,
    required this.privacy,
  });

  final List<_MonthTotals> monthly;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final Decimal totalIng = monthly.fold(
        Decimal.zero, (Decimal acc, _MonthTotals m) => acc + m.ingresos);
    final Decimal totalGas = monthly.fold(
        Decimal.zero, (Decimal acc, _MonthTotals m) => acc + m.gastos);
    final Decimal totalBal = totalIng - totalGas;

    return Column(
      children: [
        // center (no stretch): evita "infinite height" del Row en scroll; los
        // dos tiles son idénticos en estructura ⇒ misma altura igual.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _TotalTile(
                label: 'Ingresos del año',
                value: totalIng,
                kind: AmountKind.ingreso,
                currency: currency,
                privacy: privacy,
              ),
            ),
            const SizedBox(width: Insets.xl),
            Expanded(
              child: _TotalTile(
                label: 'Gastos del año',
                value: totalGas,
                kind: AmountKind.gasto,
                currency: currency,
                privacy: privacy,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        _TotalTile(
          label: 'Balance del año',
          value: totalBal,
          kind: AmountKind.balance,
          currency: currency,
          privacy: privacy,
        ),
      ],
    );
  }
}

/// Tile de total: etiqueta + monto serif.
class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.kind,
    required this.currency,
    required this.privacy,
  });

  final String label;
  final Decimal value;
  final AmountKind kind;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      padding: const EdgeInsets.all(Insets.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          AmountText(
            value: value,
            currencyCode: currency,
            kind: kind,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifAmount(c.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Chart ─────────────────────────────────────

/// BarChart de los 12 meses (ingreso sage vs gasto coral, agrupados). Espejo
/// del `chartCard` de iOS.
class _AnnualChartCard extends StatelessWidget {
  const _AnnualChartCard({required this.monthly, required this.currency});

  final List<_MonthTotals> monthly;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    double maxVal = 0;
    for (final _MonthTotals m in monthly) {
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
          Text('Evolución mensual', style: AppText.h2(c.textPrimary)),
          const SizedBox(height: Insets.cardLg),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceBetween,
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
                      reservedSize: 22,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int i = value.toInt();
                        if (i < 0 || i >= monthly.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            _monthInitial(monthly[i].month),
                            style: AppText.caption(c.textMuted)
                                .copyWith(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < monthly.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 2,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: monthly[i].ingresos.toDouble(),
                          color: c.brandSuccess,
                          width: 5,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                        BarChartRodData(
                          toY: monthly[i].gastos.toDouble(),
                          color: c.brandDanger,
                          width: 5,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
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

  /// Inicial del mes en es-AR (1 letra para el eje X apretado de 12 meses).
  static String _monthInitial(int month) {
    const List<String> initials = <String>[
      '',
      'E',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D',
    ];
    if (month < 1 || month > 12) return '';
    return initials[month];
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

// ─────────────────────────────── Months grid ───────────────────────────────

/// Grilla 2-col con el detalle por mes (ingreso ↑ / gasto ↓ / balance). Espejo
/// del `monthsGrid` de iOS.
class _MonthsGrid extends StatelessWidget {
  const _MonthsGrid({
    required this.monthly,
    required this.currency,
    required this.privacy,
  });

  final List<_MonthTotals> monthly;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Insets.xl,
      crossAxisSpacing: Insets.xl,
      childAspectRatio: 1.45,
      children: <Widget>[
        for (final _MonthTotals m in monthly)
          _MonthCell(month: m, currency: currency, privacy: privacy),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.month,
    required this.currency,
    required this.privacy,
  });

  final _MonthTotals month;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Insets.card),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_monthName(month.month).toUpperCase(),
              style: AppText.label(c.textMuted)),
          Row(
            children: [
              Icon(LucideIcons.arrowUp, size: 11, color: c.brandSuccess),
              const SizedBox(width: Insets.xs),
              Flexible(
                child: AmountText(
                  value: month.ingresos,
                  currencyCode: currency,
                  kind: AmountKind.neutro,
                  obscured: privacy,
                  moneyStyle: MoneyStyle.abbreviated,
                  style: AppText.caption(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(LucideIcons.arrowDown, size: 11, color: c.brandDanger),
              const SizedBox(width: Insets.xs),
              Flexible(
                child: AmountText(
                  value: month.gastos,
                  currencyCode: currency,
                  kind: AmountKind.neutro,
                  obscured: privacy,
                  moneyStyle: MoneyStyle.abbreviated,
                  style: AppText.caption(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          AmountText(
            value: month.balance,
            currencyCode: currency,
            kind: AmountKind.balance,
            obscured: privacy,
            moneyStyle: MoneyStyle.abbreviated,
            style: AppText.caption(c.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Nombre corto del mes (3 letras, es-AR).
  static String _monthName(int month) {
    const List<String> months = <String>[
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    if (month < 1 || month > 12) return '';
    return months[month];
  }
}

// ─────────────────────────────── Error ─────────────────────────────────────

/// Error inline con reintento (dentro del ListView).
class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: EmptyState(
        icon: LucideIcons.cloudOff,
        title: 'No pudimos cargar el año',
        message: 'Revisá tu conexión y volvé a intentar.',
        actionLabel: 'Reintentar',
        onAction: onRetry,
      ),
    );
  }
}
