import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
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

/// Celda-día del heatmap: fecha, columna (semana 0-based), fila (día de la
/// semana Dom=0..Sáb=6) y monto gastado ese día. Espejo de `DayCell` (iOS).
class _DayCell {
  const _DayCell({
    required this.date,
    required this.column,
    required this.weekday,
    required this.amount,
  });

  final DateTime date;
  final int column;
  final int weekday;
  final Decimal amount;
}

/// Quintiles del gasto diario (no-cero). Da el bucket 0-4 de intensidad. Espejo
/// de `Quintiles` (iOS): se adapta al volumen del usuario (no thresholds fijos).
class _Quintiles {
  const _Quintiles({
    required this.q1,
    required this.q2,
    required this.q3,
    required this.q4,
  });

  final Decimal q1;
  final Decimal q2;
  final Decimal q3;
  final Decimal q4;

  /// 0 = sin gasto; 1-4 = intensidad creciente. Espejo de `bucket(for:)`.
  int bucket(Decimal amount) {
    if (amount <= Decimal.zero) return 0;
    if (amount < q1) return 1;
    if (amount < q2) return 2;
    if (amount < q3) return 3;
    return 4;
  }
}

/// Mapa de gasto — espejo de `SpendingHeatmapView` (iOS). Grilla estilo GitHub
/// (7 filas × ~52 columnas) donde la intensidad del color refleja cuánto se
/// gastó cada día. Pushada desde Reportes con `Navigator.push`.
///
/// - Eje Y = día de la semana (Dom-Sáb).
/// - Eje X = semanas del año (scroll horizontal).
/// - Color: 5 niveles por quintiles del gasto diario (se adapta al volumen).
/// - Tap en una celda → card con fecha + monto exacto.
class SpendingHeatmapScreen extends ConsumerStatefulWidget {
  const SpendingHeatmapScreen({super.key});

  @override
  ConsumerState<SpendingHeatmapScreen> createState() =>
      _SpendingHeatmapScreenState();
}

class _SpendingHeatmapScreenState extends ConsumerState<SpendingHeatmapScreen> {
  late int _year;
  Map<int, Decimal> _dailyTotals = const <int, Decimal>{}; // clave = yyyymmdd
  bool _loading = false;
  Object? _error;
  _DayCell? _selected;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Trae los GASTOS del año y los acumula por día. Espejo del `load()` de iOS.
  Future<void> _load() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (!mounted) return;
    if (householdId == null) {
      setState(() {
        _dailyTotals = const <int, Decimal>{};
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });

    try {
      final DateTime from = DateTime(_year, 1, 1);
      final DateTime to = DateTime(_year, 12, 31, 23, 59, 59);
      final List<Transaction> txs =
          await ref.read(transactionRepositoryProvider).fetchRange(
                householdId: householdId,
                from: from,
                to: to,
                limit: 20000,
              );
      if (!mounted) return;
      final Map<int, Decimal> totals = <int, Decimal>{};
      for (final Transaction tx in txs.excludingTransfers) {
        if (tx.type != TxType.gasto) continue;
        final int key =
            tx.date.year * 10000 + tx.date.month * 100 + tx.date.day;
        totals[key] = (totals[key] ?? Decimal.zero) + tx.amountInBase;
      }
      setState(() {
        _dailyTotals = totals;
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
    final int maxYear = DateTime.now().year;
    final int next = _year + delta;
    if (next < 2000 || next > maxYear) return;
    HapticFeedback.selectionClick();
    setState(() => _year = next);
    _load();
  }

  /// Construye todas las celdas del año. La COLUMNA es la cantidad de semanas
  /// (de domingo a domingo) transcurridas desde el primer domingo en/antes del
  /// 1 de enero — así el layout queda alineado tipo GitHub. La FILA es el día
  /// de la semana (Dom=0..Sáb=6). Reemplaza el `weekOfYear` de iOS por un
  /// cálculo determinístico (Dart no expone `weekOfYear`).
  List<_DayCell> _buildCells() {
    final DateTime jan1 = DateTime(_year, 1, 1);
    // weekday en Dart: lun=1..dom=7. Lo pasamos a Dom=0..Sáb=6.
    final int jan1Weekday = jan1.weekday % 7; // dom(7)→0, lun(1)→1…
    // Domingo de la semana que contiene el 1 de enero (ancla de columnas).
    final DateTime gridStart = jan1.subtract(Duration(days: jan1Weekday));
    final int daysInYear = DateTime(_year, 12, 31).difference(jan1).inDays + 1;

    final List<_DayCell> cells = <_DayCell>[];
    for (int offset = 0; offset < daysInYear; offset++) {
      final DateTime date = DateTime(_year, 1, 1 + offset);
      final int weekday = date.weekday % 7; // Dom=0..Sáb=6
      final int column = date.difference(gridStart).inDays ~/ 7;
      final int key = date.year * 10000 + date.month * 100 + date.day;
      cells.add(_DayCell(
        date: date,
        column: column,
        weekday: weekday,
        amount: _dailyTotals[key] ?? Decimal.zero,
      ));
    }
    return cells;
  }

  /// Quintiles sobre los gastos diarios no-cero. Espejo de `computeQuintiles`.
  _Quintiles _computeQuintiles(List<_DayCell> cells) {
    final List<Decimal> nonZero = cells
        .map((_DayCell c) => c.amount)
        .where((Decimal a) => a > Decimal.zero)
        .toList()
      ..sort((Decimal a, Decimal b) => a.compareTo(b));

    if (nonZero.length < 5) {
      final Decimal max = nonZero.isEmpty ? Decimal.zero : nonZero.last;
      final Decimal five = Decimal.fromInt(5);
      return _Quintiles(
        q1: (max / five).toDecimal(scaleOnInfinitePrecision: 6),
        q2: (max * Decimal.fromInt(2) / five)
            .toDecimal(scaleOnInfinitePrecision: 6),
        q3: (max * Decimal.fromInt(3) / five)
            .toDecimal(scaleOnInfinitePrecision: 6),
        q4: (max * Decimal.fromInt(4) / five)
            .toDecimal(scaleOnInfinitePrecision: 6),
      );
    }
    final int n = nonZero.length;
    return _Quintiles(
      q1: nonZero[n ~/ 5],
      q2: nonZero[2 * n ~/ 5],
      q3: nonZero[3 * n ~/ 5],
      q4: nonZero[4 * n ~/ 5],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final String currency =
        ref.watch(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
            'USD';

    final List<_DayCell> cells = _buildCells();
    final _Quintiles quintiles = _computeQuintiles(cells);

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Mapa de gasto', style: AppText.h2(c.textPrimary)),
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
            _InlineError(onRetry: _load)
          else ...[
            _StatsHeader(dailyTotals: _dailyTotals, currency: currency),
            const SizedBox(height: Insets.section),
            _HeatmapGrid(
              cells: cells,
              quintiles: quintiles,
              selected: _selected,
              onTap: (_DayCell cell) {
                HapticFeedback.selectionClick();
                setState(() => _selected = cell);
              },
            ),
            const SizedBox(height: Insets.card),
            const _Legend(),
            if (_selected != null) ...[
              const SizedBox(height: Insets.section),
              _SelectedCard(cell: _selected!, currency: currency),
            ],
            const SizedBox(height: Insets.section),
            Text(
              'Cada cuadrito es un día. Más oscuro = más gasto.',
              style: AppText.caption(c.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Year picker ───────────────────────────────

/// Picker ‹ Año › (tope = año actual). Espejo del `yearPicker` de iOS.
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

// ─────────────────────────────── Stats header ──────────────────────────────

/// Resumen: gasto total del año, días activos y promedio por día activo.
/// Espejo del `statsHeader` de iOS. No es privacy-aware (matchea iOS, que
/// muestra los stats siempre).
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.dailyTotals, required this.currency});

  final Map<int, Decimal> dailyTotals;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final Decimal total = dailyTotals.values
        .fold(Decimal.zero, (Decimal acc, Decimal v) => acc + v);
    final int activeDays =
        dailyTotals.values.where((Decimal v) => v > Decimal.zero).length;
    final Decimal avg = activeDays > 0
        ? (total / Decimal.fromInt(activeDays))
            .toDecimal(scaleOnInfinitePrecision: 6)
        : Decimal.zero;

    // center (no stretch): evita "infinite height" del Row en scroll; los
    // tiles son idénticos en estructura ⇒ misma altura igual.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _Stat(
            label: 'Gasto del año',
            value: Money.format(total,
                currencyCode: currency, style: MoneyStyle.abbreviated),
          ),
        ),
        const SizedBox(width: Insets.xl),
        Expanded(child: _Stat(label: 'Días activos', value: '$activeDays')),
        const SizedBox(width: Insets.xl),
        Expanded(
          child: _Stat(
            label: 'Prom. por día',
            value: Money.format(avg,
                currencyCode: currency, style: MoneyStyle.abbreviated),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.serifInline(c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Heatmap grid ──────────────────────────────

const double _kCellSize = 13;
const double _kCellGap = 4;

/// Color de una intensidad 0-4. Espejo de `colorFor(intensity:)` de iOS:
/// 0 = superficie inset; 1-4 = sage glow con opacidad creciente.
Color _intensityColor(MidnightSageColors c, int intensity) =>
    switch (intensity) {
      0 => c.appSurfaceInset,
      1 => c.brandPrimary.withValues(alpha: 0.25),
      2 => c.brandPrimary.withValues(alpha: 0.45),
      3 => c.brandPrimary.withValues(alpha: 0.70),
      _ => c.brandPrimary,
    };

/// Grilla scrollable horizontal: columna de labels de día (L/M/V) + N columnas
/// de semanas, cada una con 7 celdas. Espejo del `heatmapGrid` de iOS.
class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({
    required this.cells,
    required this.quintiles,
    required this.selected,
    required this.onTap,
  });

  final List<_DayCell> cells;
  final _Quintiles quintiles;
  final _DayCell? selected;
  final ValueChanged<_DayCell> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Agrupamos por columna (semana). Dentro de cada columna, por weekday.
    final int maxColumn = cells.fold<int>(
        0, (int acc, _DayCell cell) => cell.column > acc ? cell.column : acc);
    final Map<int, Map<int, _DayCell>> byColumn = <int, Map<int, _DayCell>>{};
    for (final _DayCell cell in cells) {
      (byColumn[cell.column] ??= <int, _DayCell>{})[cell.weekday] = cell;
    }

    return MCCard(
      padding: const EdgeInsets.all(Insets.card),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eje Y: labels de día (Dom=0..Sáb=6 → L, M, V en posiciones 1/3/5).
            Padding(
              padding: const EdgeInsets.only(right: Insets.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (int wd = 0; wd < 7; wd++)
                    SizedBox(
                      height: _kCellSize + _kCellGap,
                      child: Text(
                        _dayLabel(wd),
                        style: AppText.caption(c.textMuted)
                            .copyWith(fontSize: 9, height: 1),
                      ),
                    ),
                ],
              ),
            ),
            // Columnas de semanas.
            for (int col = 0; col <= maxColumn; col++)
              Padding(
                padding: const EdgeInsets.only(right: _kCellGap),
                child: Column(
                  children: <Widget>[
                    for (int wd = 0; wd < 7; wd++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: _kCellGap),
                        child: _cell(c, byColumn[col]?[wd]),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Una celda: cuadrito coloreado por intensidad; si está seleccionada, borde
  /// sage. Las posiciones sin día (fuera del año) van transparentes.
  Widget _cell(MidnightSageColors c, _DayCell? cell) {
    if (cell == null) {
      return const SizedBox(width: _kCellSize, height: _kCellSize);
    }
    final int intensity = quintiles.bucket(cell.amount);
    final bool isSelected = selected != null &&
        selected!.date.year == cell.date.year &&
        selected!.date.month == cell.date.month &&
        selected!.date.day == cell.date.day;

    return GestureDetector(
      onTap: () => onTap(cell),
      child: Container(
        width: _kCellSize,
        height: _kCellSize,
        decoration: ShapeDecoration(
          color: _intensityColor(c, intensity),
          shape: SmoothRectangleBorder(
            borderRadius: Radii.smooth(3, smoothing: 0.6),
            side: isSelected
                ? BorderSide(color: c.brandPrimary, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Label de fila por weekday (Dom=0..Sáb=6): solo mostramos L/M/V (como iOS).
  static String _dayLabel(int weekday) => switch (weekday) {
        1 => 'L',
        3 => 'M',
        5 => 'V',
        _ => ' ',
      };
}

// ─────────────────────────────── Legend ────────────────────────────────────

/// Leyenda menos → más (5 cuadritos). Espejo del `legend` de iOS.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text('menos',
            style: AppText.caption(c.textMuted).copyWith(fontSize: 10)),
        const SizedBox(width: Insets.sm),
        for (int i = 0; i <= 4; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 12,
              height: 12,
              decoration: ShapeDecoration(
                color: _intensityColor(c, i),
                shape: SmoothRectangleBorder(
                  borderRadius: Radii.smooth(3, smoothing: 0.6),
                ),
              ),
            ),
          ),
        const SizedBox(width: Insets.xs),
        Text('más', style: AppText.caption(c.textMuted).copyWith(fontSize: 10)),
      ],
    );
  }
}

// ─────────────────────────────── Selected card ─────────────────────────────

/// Card del día seleccionado: fecha legible + monto. Espejo del `selectedCard`
/// de iOS. Coral si gastó, neutro si no.
class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.cell, required this.currency});

  final _DayCell cell;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool spent = cell.amount > Decimal.zero;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_longDate(cell.date), style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          AmountText(
            value: cell.amount,
            currencyCode: currency,
            kind: spent ? AmountKind.gasto : AmountKind.neutro,
            moneyStyle: MoneyStyle.auto,
            style: AppText.serifAmount(c.textPrimary),
          ),
          if (!spent) ...[
            const SizedBox(height: Insets.xs),
            Text('Sin gastos este día', style: AppText.caption(c.textMuted)),
          ],
        ],
      ),
    );
  }

  /// "Lunes 3 de marzo de 2026" (es-AR, manual).
  static String _longDate(DateTime d) {
    const List<String> weekdays = <String>[
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const List<String> months = <String>[
      '',
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final String wd = weekdays[d.weekday];
    final String mo = months[d.month];
    return '$wd ${d.day} de $mo de ${d.year}';
  }
}

// ─────────────────────────────── Error ─────────────────────────────────────

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
        title: 'No pudimos cargar el mapa',
        message: 'Revisá tu conexión y volvé a intentar.',
        actionLabel: 'Reintentar',
        onAction: onRetry,
      ),
    );
  }
}
