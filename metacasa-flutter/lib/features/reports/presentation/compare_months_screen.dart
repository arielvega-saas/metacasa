import 'package:decimal/decimal.dart';
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

/// Totales (ingresos/gastos) de un período. Tipo local liviano para no
/// arrastrar el `TransactionTotals` del repo (que suma `amount`, no
/// `amountInBase`).
class _Totals {
  const _Totals({required this.ingresos, required this.gastos});

  final Decimal ingresos;
  final Decimal gastos;

  Decimal get balance => ingresos - gastos;
}

/// Fila de comparación de categoría: gasto en mes A vs mes B.
class _CatRow {
  const _CatRow({required this.category, required this.a, required this.b});

  final String category;
  final Decimal a;
  final Decimal b;

  /// El mayor de los dos (para ordenar las filas por relevancia).
  Decimal get peak => a > b ? a : b;
}

/// Comparar meses — espejo de `CompareMonthsView` (iOS). Pantalla auto-contenida
/// con dos meses elegibles. Pushada desde Reportes con `Navigator.push`.
///
/// Estructura:
///   1. Dos pickers de mes (A = mes anterior, B = mes actual por default).
///   2. Totales lado a lado (ingresos / gastos / balance) con Δ (verde si
///      mejora: para gastos bajar es bueno; para ingresos/balance subir).
///   3. Top-8 categorías de gasto comparadas (BarChart agrupado A vs B).
class CompareMonthsScreen extends ConsumerStatefulWidget {
  const CompareMonthsScreen({super.key});

  @override
  ConsumerState<CompareMonthsScreen> createState() =>
      _CompareMonthsScreenState();
}

class _CompareMonthsScreenState extends ConsumerState<CompareMonthsScreen> {
  late ({int year, int month}) _monthA;
  late ({int year, int month}) _monthB;

  List<Transaction> _txsA = const <Transaction>[];
  List<Transaction> _txsB = const <Transaction>[];
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    final DateTime prev = DateTime(now.year, now.month - 1, 1);
    _monthA = (year: prev.year, month: prev.month);
    _monthB = (year: now.year, month: now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  /// Trae ambos meses en paralelo (`fetchRange` por rango de mes). Espejo del
  /// `reload()` de iOS (async let a/b).
  Future<void> _reload() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (!mounted) return;
    if (householdId == null) {
      setState(() {
        _txsA = const <Transaction>[];
        _txsB = const <Transaction>[];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final TransactionRepository repo =
          ref.read(transactionRepositoryProvider);
      final (DateTime, DateTime) ra = _monthRange(_monthA);
      final (DateTime, DateTime) rb = _monthRange(_monthB);
      final Future<List<Transaction>> fa = repo.fetchRange(
          householdId: householdId, from: ra.$1, to: ra.$2, limit: 5000);
      final Future<List<Transaction>> fb = repo.fetchRange(
          householdId: householdId, from: rb.$1, to: rb.$2, limit: 5000);
      final List<Transaction> a = await fa;
      final List<Transaction> b = await fb;
      if (!mounted) return;
      setState(() {
        _txsA = a;
        _txsB = b;
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

  static (DateTime, DateTime) _monthRange(({int year, int month}) ym) {
    final DateTime start = DateTime(ym.year, ym.month, 1);
    final DateTime end = DateTime(ym.year, ym.month + 1, 0, 23, 59, 59);
    return (start, end);
  }

  static _Totals _totalsOf(List<Transaction> txs) {
    var ing = Decimal.zero;
    var gas = Decimal.zero;
    for (final Transaction tx in txs) {
      switch (tx.type) {
        case TxType.ingreso:
          ing += tx.amountInBase;
        case TxType.gasto:
          gas += tx.amountInBase;
      }
    }
    return _Totals(ingresos: ing, gastos: gas);
  }

  static Map<String, Decimal> _gastoByCategory(List<Transaction> txs) {
    final Map<String, Decimal> out = <String, Decimal>{};
    for (final Transaction tx in txs) {
      if (tx.type != TxType.gasto) continue;
      out[tx.category] = (out[tx.category] ?? Decimal.zero) + tx.amountInBase;
    }
    return out;
  }

  Future<void> _pickMonth(bool isA) async {
    final ({int year, int month}) current = isA ? _monthA : _monthB;
    final DateTime now = DateTime.now();
    final DateTime initial = DateTime(current.year, current.month);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialDatePickerMode: DatePickerMode.year,
      helpText: isA ? 'Elegí el mes A' : 'Elegí el mes B',
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      final ({int year, int month}) ym =
          (year: picked.year, month: picked.month);
      if (isA) {
        _monthA = ym;
      } else {
        _monthB = ym;
      }
    });
    await _reload();
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
        title: Text('Comparar meses', style: AppText.h2(c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.md,
          Insets.screen,
          Insets.xxl,
        ),
        children: [
          _PickersCard(
            monthA: _monthA,
            monthB: _monthB,
            onPickA: () => _pickMonth(true),
            onPickB: () => _pickMonth(false),
          ),
          const SizedBox(height: Insets.section),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _InlineError(onRetry: _reload)
          else ...[
            _TotalsCard(
              totalsA: _totalsOf(_txsA),
              totalsB: _totalsOf(_txsB),
              currency: currency,
              privacy: privacy,
            ),
            const SizedBox(height: Insets.section),
            _CompareCategoriesCard(
              byCatA: _gastoByCategory(_txsA),
              byCatB: _gastoByCategory(_txsB),
              currency: currency,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Pickers ───────────────────────────────────

/// Card con los dos selectores de mes. Espejo del `pickersCard` de iOS.
class _PickersCard extends StatelessWidget {
  const _PickersCard({
    required this.monthA,
    required this.monthB,
    required this.onPickA,
    required this.onPickB,
  });

  final ({int year, int month}) monthA;
  final ({int year, int month}) monthB;
  final VoidCallback onPickA;
  final VoidCallback onPickB;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        children: [
          _MonthPickerRow(
            label: 'Mes A',
            value: _MonthFmt.long(monthA),
            accent: c.brandSecondary,
            onTap: onPickA,
          ),
          const SizedBox(height: Insets.card),
          Divider(color: c.appBorder, height: 1),
          const SizedBox(height: Insets.card),
          _MonthPickerRow(
            label: 'Mes B',
            value: _MonthFmt.long(monthB),
            accent: c.brandPrimary,
            onTap: onPickB,
          ),
        ],
      ),
    );
  }
}

class _MonthPickerRow extends StatelessWidget {
  const _MonthPickerRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 16, color: accent),
            const SizedBox(width: Insets.md),
            Text(label, style: AppText.label(c.textMuted)),
            const Spacer(),
            Text(
              value,
              style: AppText.body(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: Insets.sm),
            Icon(LucideIcons.chevronDown, size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Totales ───────────────────────────────────

/// Totales lado a lado con Δ. Espejo del `totalsCard` de iOS.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.totalsA,
    required this.totalsB,
    required this.currency,
    required this.privacy,
  });

  final _Totals totalsA;
  final _Totals totalsB;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Totales', style: AppText.h2(c.textPrimary)),
          const SizedBox(height: Insets.cardLg),
          _CompareRow(
            label: 'Ingresos',
            valueA: totalsA.ingresos,
            valueB: totalsB.ingresos,
            kind: AmountKind.ingreso,
            currency: currency,
            privacy: privacy,
          ),
          Divider(color: c.appBorder, height: Insets.xxl),
          _CompareRow(
            label: 'Gastos',
            valueA: totalsA.gastos,
            valueB: totalsB.gastos,
            kind: AmountKind.gasto,
            currency: currency,
            privacy: privacy,
          ),
          Divider(color: c.appBorder, height: Insets.xxl),
          _CompareRow(
            label: 'Balance',
            valueA: totalsA.balance,
            valueB: totalsB.balance,
            kind: AmountKind.balance,
            currency: currency,
            privacy: privacy,
          ),
        ],
      ),
    );
  }
}

/// Una fila de comparación: etiqueta + (A, B) + Δ coloreado por mejora. Espejo
/// del `compareRow` + `deltaColor` de iOS.
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.valueA,
    required this.valueB,
    required this.kind,
    required this.currency,
    required this.privacy,
  });

  final String label;
  final Decimal valueA;
  final Decimal valueB;
  final AmountKind kind;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Decimal delta = valueB - valueA;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ValueCol(
                tag: 'Mes A',
                value: valueA,
                kind: kind,
                currency: currency,
                privacy: privacy,
              ),
            ),
            Expanded(
              child: _ValueCol(
                tag: 'Mes B',
                value: valueB,
                kind: kind,
                currency: currency,
                privacy: privacy,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Δ', style: AppText.caption(c.textDim)),
                const SizedBox(height: Insets.xxs),
                Text(
                  privacy ? '••••' : _deltaLabel(delta),
                  style: AppText.serifInline(_deltaColor(c, delta)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _deltaLabel(Decimal delta) {
    final String sign = delta >= Decimal.zero ? '+' : '';
    return '$sign${Money.format(delta, currencyCode: currency, locale: 'es_AR')}';
  }

  /// Para gastos, bajar (Δ<0) es mejora → verde. Para ingresos/balance, subir
  /// (Δ>0) es mejora. Δ==0 neutro. Espejo del `deltaColor` de iOS.
  Color _deltaColor(MidnightSageColors c, Decimal delta) {
    if (delta == Decimal.zero) return c.textMuted;
    final bool improvement =
        kind == AmountKind.gasto ? delta < Decimal.zero : delta > Decimal.zero;
    return improvement ? c.brandSuccess : c.brandDanger;
  }
}

/// Columna A o B: tag chico + monto inline.
class _ValueCol extends StatelessWidget {
  const _ValueCol({
    required this.tag,
    required this.value,
    required this.kind,
    required this.currency,
    required this.privacy,
  });

  final String tag;
  final Decimal value;
  final AmountKind kind;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tag, style: AppText.caption(c.textDim)),
        const SizedBox(height: Insets.xxs),
        AmountText(
          value: value,
          currencyCode: currency,
          kind: kind,
          obscured: privacy,
          moneyStyle: MoneyStyle.compact,
          style: AppText.serifInline(c.textPrimary),
        ),
      ],
    );
  }
}

// ─────────────────────────── Categorías comparadas ─────────────────────────

/// Top-8 categorías de gasto comparadas (A champagne vs B sage) en un BarChart
/// agrupado vertical. Espejo del `topCategoriesCard` de iOS (que usa barras
/// horizontales; acá agrupamos vertical, más natural en `fl_chart`).
class _CompareCategoriesCard extends StatelessWidget {
  const _CompareCategoriesCard({
    required this.byCatA,
    required this.byCatB,
    required this.currency,
  });

  final Map<String, Decimal> byCatA;
  final Map<String, Decimal> byCatB;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final Set<String> allCats = <String>{...byCatA.keys, ...byCatB.keys};
    final List<_CatRow> rows = allCats
        .map((String cat) => _CatRow(
              category: cat,
              a: byCatA[cat] ?? Decimal.zero,
              b: byCatB[cat] ?? Decimal.zero,
            ))
        .toList()
      ..sort((_CatRow x, _CatRow y) => y.peak.compareTo(x.peak));
    final List<_CatRow> top = rows.take(8).toList();

    double maxVal = 0;
    for (final _CatRow r in top) {
      final double a = r.a.toDouble();
      final double b = r.b.toDouble();
      if (a > maxVal) maxVal = a;
      if (b > maxVal) maxVal = b;
    }
    final double maxY = maxVal <= 0 ? 1 : maxVal * 1.12;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gastos por categoría', style: AppText.h2(c.textPrimary)),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              _LegendDot(color: c.brandSecondary, label: 'Mes A'),
              const SizedBox(width: Insets.xl),
              _LegendDot(color: c.brandPrimary, label: 'Mes B'),
            ],
          ),
          const SizedBox(height: Insets.cardLg),
          if (top.isEmpty)
            _InlineEmpty(
              icon: LucideIcons.barChart3,
              message: 'No hay gastos en ninguno de los dos meses.',
            )
          else
            SizedBox(
              height: top.length * 42 + 30,
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
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int i = value.toInt();
                          if (i < 0 || i >= top.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              CategoryCatalog.emojiFor(top[i].category),
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: <BarChartGroupData>[
                    for (int i = 0; i < top.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: top[i].a.toDouble(),
                            color: c.brandSecondary,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: top[i].b.toDouble(),
                            color: c.brandPrimary,
                            width: 8,
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
        ],
      ),
    );
  }
}

// ─────────────────────────────── Shared bits ───────────────────────────────

/// Formato de mes legible (es-AR).
abstract final class _MonthFmt {
  static const List<String> _names = <String>[
    '',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// "Marzo 2026".
  static String long(({int year, int month}) ym) {
    if (ym.month < 1 || ym.month > 12) return '${ym.year}';
    return '${_names[ym.month]} ${ym.year}';
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

/// Empty-state inline (dentro de una card).
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
          Expanded(child: Text(message, style: AppText.caption(c.textMuted))),
        ],
      ),
    );
  }
}

/// Error inline con reintento.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: EmptyState(
        icon: LucideIcons.cloudOff,
        title: 'No pudimos comparar los meses',
        message: 'Revisá tu conexión y volvé a intentar.',
        actionLabel: 'Reintentar',
        onAction: onRetry,
      ),
    );
  }
}
