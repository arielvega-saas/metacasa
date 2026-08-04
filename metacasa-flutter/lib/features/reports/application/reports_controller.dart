import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance/balance_calculator.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Banda cualitativa del health score. Espejo de la lógica de color/label del
/// `healthScoreCard` de iOS (`ReportsView.swift`):
///   ≥75 excellent · ≥55 good · ≥35 fair · resto poor.
enum HealthBand {
  excellent,
  good,
  fair,
  poor;

  /// Etiqueta legible (es-AR), espejo de las claves `reports.health.*` del iOS.
  String get label => switch (this) {
        HealthBand.excellent => 'Excelente',
        HealthBand.good => 'Saludable',
        HealthBand.fair => 'Regular',
        HealthBand.poor => 'A mejorar',
      };

  /// Mapea un score 0–100 a su banda (umbrales idénticos a iOS).
  static HealthBand fromScore(int score) {
    if (score >= 75) return HealthBand.excellent;
    if (score >= 55) return HealthBand.good;
    if (score >= 35) return HealthBand.fair;
    return HealthBand.poor;
  }
}

/// Resumen de un mes para la serie de 6 meses. Espejo de `MonthlySummary`
/// (iOS `ReportsView.swift`) y de `MonthTotals` (iOS `AnnualView.swift`).
class MonthlySummary {
  const MonthlySummary({
    required this.year,
    required this.month,
    required this.label,
    required this.ingresos,
    required this.gastos,
  });

  /// Año calendario del mes.
  final int year;

  /// Mes calendario (1–12).
  final int month;

  /// Etiqueta corta del mes (es-AR, 3 letras: "ene", "feb"…).
  final String label;

  /// Σ `amountInBase` de los movimientos INGRESO del mes.
  final Decimal ingresos;

  /// Σ `amountInBase` de los movimientos GASTO del mes.
  final Decimal gastos;

  /// Balance del mes (ingresos − gastos).
  Decimal get balance => ingresos - gastos;
}

/// Tajada del Pareto: una categoría de gasto con su monto y su % sobre el total
/// del período. Espejo de `CategorySlice` (iOS `ReportsView.swift`).
class CategorySlice {
  const CategorySlice({
    required this.category,
    required this.amount,
    required this.percent,
  });

  /// Nombre de la categoría.
  final String category;

  /// Σ `amountInBase` gastado en la categoría (período Pareto = mes actual).
  final Decimal amount;

  /// Proporción [0,1] del gasto total que concentra esta categoría.
  final double percent;
}

/// Estado inmutable de Reportes. Clase plana (sin freezed/codegen, por
/// requerimiento) con todas las cifras ya computadas con [Decimal] donde es
/// dinero y `double` solo para ratios/score.
///
/// Espejo de los datos derivados de `ReportsView` (iOS): health score + banda,
/// serie de 6 meses (ingreso vs gasto) y Pareto 80/20 de categorías del mes.
class ReportsState {
  const ReportsState({
    required this.healthScore,
    required this.band,
    required this.savingsRate,
    required this.sixMonths,
    required this.pareto,
  });

  /// Estado vacío (sin hogar o sin movimientos): score 0, listas vacías.
  factory ReportsState.empty() => const ReportsState(
        healthScore: 0,
        band: HealthBand.poor,
        savingsRate: 0,
        sixMonths: <MonthlySummary>[],
        pareto: <CategorySlice>[],
      );

  /// Health score 0–100 (entero, igual que iOS).
  final int healthScore;

  /// Banda cualitativa derivada del [healthScore].
  final HealthBand band;

  /// Tasa de ahorro del rango de 6 meses, [0,1] (para el subtítulo del score).
  /// `(ingresos − gastos) / ingresos`, clampeada a 0 si los ingresos son 0.
  final double savingsRate;

  /// Serie de los últimos 6 meses (más antiguo → actual). Espejo de
  /// `sixMonthData` (iOS), siempre con 6 entradas.
  final List<MonthlySummary> sixMonths;

  /// Pareto de gasto del MES ACTUAL, ordenado desc por monto. Espejo de
  /// `paretoData` (iOS): incluye todas las categorías; la UI corta a top 8 para
  /// el donut y muestra el resto en el breakdown.
  final List<CategorySlice> pareto;

  /// Σ ingresos del rango de 6 meses.
  Decimal get totalIngresos => sixMonths.fold(
      Decimal.zero, (Decimal acc, MonthlySummary m) => acc + m.ingresos);

  /// Σ gastos del rango de 6 meses.
  Decimal get totalGastos => sixMonths.fold(
      Decimal.zero, (Decimal acc, MonthlySummary m) => acc + m.gastos);

  /// Σ gasto total del mes Pareto (denominador de los %).
  Decimal get paretoTotal => pareto.fold(
      Decimal.zero, (Decimal acc, CategorySlice s) => acc + s.amount);

  /// `true` si no hay nada para mostrar (sin movimientos en el rango ni Pareto).
  bool get isEmpty =>
      totalIngresos == Decimal.zero &&
      totalGastos == Decimal.zero &&
      pareto.isEmpty;
}

/// Controller de Reportes. `AsyncNotifier` que observa el hogar activo y carga
/// los últimos 6 meses de movimientos (`fetchRange`), computa la serie mensual,
/// el Pareto del mes actual y el health score con las MISMAS fórmulas de iOS.
///
/// NOTA: a diferencia del Home, Reportes NO depende del período navegado: usa
/// SIEMPRE el reloj real del device como ancla (los últimos 6 meses hasta hoy),
/// igual que `ReportsView.load()` en iOS.
class ReportsController extends AsyncNotifier<ReportsState> {
  @override
  Future<ReportsState> build() async {
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) return ReportsState.empty();
    return _load(householdId);
  }

  /// Carga + cómputo. Replica el `load()` de iOS: trae 6 meses hacia atrás y
  /// deriva serie, Pareto y score en memoria con [Decimal].
  Future<ReportsState> _load(String householdId) async {
    final TransactionRepository txRepo =
        ref.read(transactionRepositoryProvider);

    // Ancla = ahora real. iOS toma `Date()` y `-6 meses` como `from`. Para no
    // perder el mes actual completo (y matchear el rango de la serie) pedimos
    // desde el día 1 del mes que está 5 meses atrás hasta hoy.
    final DateTime now = DateTime.now();
    final DateTime from = DateTime(now.year, now.month - 5, 1);

    final List<Transaction> txs = await txRepo.fetchRange(
      householdId: householdId,
      from: from,
      to: now,
      limit: 5000,
    );

    final List<MonthlySummary> sixMonths = _sixMonthSeries(txs, now);
    final List<CategorySlice> pareto = _paretoForMonth(txs, now);
    final (int score, double savingsRate) = _healthScore(txs, now);

    return ReportsState(
      healthScore: score,
      band: HealthBand.fromScore(score),
      savingsRate: savingsRate,
      sixMonths: sixMonths,
      pareto: pareto,
    );
  }

  /// Fuerza una recarga (pull-to-refresh). Mantiene el dato previo visible
  /// mientras recomputa.
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      state = AsyncData(ReportsState.empty());
      return;
    }
    state = const AsyncLoading<ReportsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(householdId));
  }

  // ── Serie de 6 meses ──────────────────────────────────────────────────────

  /// Construye la serie [offset 5 … 0] (más antiguo → mes actual). Para cada
  /// mes filtra los tx que caen dentro de [start, endOfMonth] y suma por tipo.
  /// Espejo 1:1 de `sixMonthData` (iOS).
  static List<MonthlySummary> _sixMonthSeries(
    List<Transaction> txs,
    DateTime now,
  ) {
    final List<MonthlySummary> result = <MonthlySummary>[];
    for (int offset = 5; offset >= 0; offset--) {
      final DateTime monthDate = DateTime(now.year, now.month - offset, 1);
      final int y = monthDate.year;
      final int m = monthDate.month;
      var ing = Decimal.zero;
      var gas = Decimal.zero;
      for (final Transaction tx in txs.excludingTransfers) {
        if (tx.date.year != y || tx.date.month != m) continue;
        switch (tx.type) {
          case TxType.ingreso:
            ing += tx.amountInBase;
          case TxType.gasto:
            gas += tx.amountInBase;
        }
      }
      result.add(MonthlySummary(
        year: y,
        month: m,
        label: _monthShort(m),
        ingresos: ing,
        gastos: gas,
      ));
    }
    return result;
  }

  // ── Pareto del mes actual ─────────────────────────────────────────────────

  /// Agrupa los GASTOS del mes [now] por categoría, calcula el % de cada una y
  /// ordena desc por monto. Espejo 1:1 de `paretoData` (iOS), que usa el mes
  /// calendario actual (no el rango completo de 6 meses).
  static List<CategorySlice> _paretoForMonth(
    List<Transaction> txs,
    DateTime now,
  ) {
    final Map<String, Decimal> byCat = <String, Decimal>{};
    var total = Decimal.zero;
    for (final Transaction tx in txs.excludingTransfers) {
      if (tx.type != TxType.gasto) continue;
      if (tx.date.year != now.year || tx.date.month != now.month) continue;
      byCat[tx.category] =
          (byCat[tx.category] ?? Decimal.zero) + tx.amountInBase;
      total += tx.amountInBase;
    }
    if (total <= Decimal.zero) return const <CategorySlice>[];

    final double totalD = total.toDouble();
    final List<CategorySlice> slices = byCat.entries
        .map((MapEntry<String, Decimal> e) => CategorySlice(
              category: e.key,
              amount: e.value,
              percent: e.value.toDouble() / totalD,
            ))
        .toList()
      ..sort(
          (CategorySlice a, CategorySlice b) => b.amount.compareTo(a.amount));
    return slices;
  }

  // ── Health score ──────────────────────────────────────────────────────────

  /// Score 0–100 + tasa de ahorro. Port 1:1 de `healthScore` (iOS), ponderando:
  ///   • Savings rate (50%): `max(0,(ing−gast)/ing) * 250`, cap 50 (20%→50pts).
  ///   • Expense ratio (30%): si `gast/ing < 1`, suma `(1−ratio) * 30`.
  ///   • Streak (20%): `min(20, díasConTx(30d) * 0.67)` (30 días → 20pts).
  /// Todo el cómputo es ratio/score → `double` (no dinero); los insumos
  /// (ingresos/gastos) se suman en [Decimal] y recién ahí se pasan a `double`.
  static (int, double) _healthScore(List<Transaction> txs, DateTime now) {
    var ing = Decimal.zero;
    var gast = Decimal.zero;
    for (final Transaction tx in txs.excludingTransfers) {
      switch (tx.type) {
        case TxType.ingreso:
          ing += tx.amountInBase;
        case TxType.gasto:
          gast += tx.amountInBase;
      }
    }

    double score = 0;
    double savingsRate = 0;

    if (ing > Decimal.zero) {
      final double ingD = ing.toDouble();
      final double gastD = gast.toDouble();
      // Savings rate (cap 50): 20% de ahorro = 50 pts.
      final double rate = ((ingD - gastD) / ingD).clamp(0.0, double.infinity);
      savingsRate = rate;
      score += (rate * 250).clamp(0.0, 50.0);
      // Expense ratio bonus (cap 30): premia gastar < 100% del ingreso.
      final double ratio = gastD / ingD;
      if (ratio < 1.0) {
        score += (1.0 - ratio) * 30;
      }
    }

    // Streak bonus (cap 20): días distintos con ≥1 tx en los últimos 30 días.
    final DateTime last30 = now.subtract(const Duration(days: 30));
    final Set<int> daysWithTx = <int>{};
    for (final Transaction tx in txs.excludingTransfers) {
      if (tx.date.isBefore(last30)) continue;
      // Clave de día calendario local (estable y única por día).
      daysWithTx.add(tx.date.year * 10000 + tx.date.month * 100 + tx.date.day);
    }
    score += (daysWithTx.length * 0.67).clamp(0.0, 20.0);

    final int clamped = score.clamp(0.0, 100.0).toInt();
    return (clamped, savingsRate);
  }

  /// Etiqueta corta del mes en es-AR (3 letras), index 1-based. Formato manual
  /// para no depender de `initializeDateFormatting` (mismo criterio que el resto
  /// de las features Flutter).
  static String _monthShort(int month) {
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

/// Provider del controller de Reportes. `AsyncNotifierProvider` (no family): el
/// controller observa `currentHouseholdProvider` internamente y se reconstruye
/// solo cuando cambia el hogar activo.
final reportsControllerProvider =
    AsyncNotifierProvider<ReportsController, ReportsState>(
        ReportsController.new);
