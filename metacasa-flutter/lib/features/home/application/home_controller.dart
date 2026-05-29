import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance/balance_calculator.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/bill_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/installment_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Par (categoría, total) para el ranking de gastos. Espejo de la tupla
/// `(category, total)` que arma el `HomeViewModel` de iOS.
class CategoryTotal {
  const CategoryTotal({required this.category, required this.total});

  final String category;
  final Decimal total;
}

/// Item del semáforo de presupuesto: un envelope (categoría) con su asignado,
/// gastado y % usado ya computado. Solo se construyen los que tienen
/// `allocated > 0` (igual que el criterio de la UI de iOS).
class BudgetSemaphoreItem {
  const BudgetSemaphoreItem({
    required this.category,
    required this.allocated,
    required this.spent,
  });

  final String category;
  final Decimal allocated;
  final Decimal spent;

  /// Saldo restante del envelope (puede ser negativo si hay sobregiro).
  Decimal get remaining => allocated - spent;

  /// % usado del envelope, clampeado a [0, 1] para la barra. El color del
  /// semáforo (en la UI) usa el % CRUDO vía `colors.budgetThreshold`, así que un
  /// overspending igual cae en coral aunque la barra se vea llena.
  double get percentUsed {
    if (allocated <= Decimal.zero) return 0;
    final double ratio = spent.toDouble() / allocated.toDouble();
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  /// % usado SIN clampear (para decidir color de umbral: >0.95 / >0.80).
  double get rawPercentUsed {
    if (allocated <= Decimal.zero) return 0;
    return spent.toDouble() / allocated.toDouble();
  }

  /// Sobregiro del envelope.
  bool get isOverBudget => spent > allocated;
}

/// Estado inmutable del dashboard. Clase plana (sin freezed/codegen, por
/// requerimiento) con todas las cifras del Home ya computadas con [Decimal].
///
/// Espejo del `HomeViewModel` de iOS: mismos totales, top categorías, daily
/// budget, proyección, net worth, bills, metas y planes de cuotas.
class HomeState {
  const HomeState({
    required this.totalIngresos,
    required this.totalGastos,
    required this.topCategories,
    required this.dailyBudget,
    required this.todayExpenses,
    required this.projectedEndOfMonth,
    required this.netWorth,
    required this.upcomingBills,
    required this.urgentBillsCount,
    required this.activeGoals,
    required this.activePlans,
    required this.budgetSemaphore,
  });

  /// Estado vacío (sin datos): todo en cero / listas vacías. Se usa como
  /// fallback cuando no hay hogar o el período no tiene movimientos.
  factory HomeState.empty() => HomeState(
        totalIngresos: Decimal.zero,
        totalGastos: Decimal.zero,
        topCategories: const <CategoryTotal>[],
        dailyBudget: Decimal.zero,
        todayExpenses: Decimal.zero,
        projectedEndOfMonth: Decimal.zero,
        netWorth: NetWorthBreakdown.zero,
        upcomingBills: const <Bill>[],
        urgentBillsCount: 0,
        activeGoals: const <Goal>[],
        activePlans: const <InstallmentPlan>[],
        budgetSemaphore: const <BudgetSemaphoreItem>[],
      );

  /// Ingresos del período: Σ `amountInBase` de los movimientos tipo INGRESO.
  final Decimal totalIngresos;

  /// Gastos del período: Σ `amountInBase` de los movimientos tipo GASTO.
  final Decimal totalGastos;

  /// Top 5 categorías de gasto (mayor a menor).
  final List<CategoryTotal> topCategories;

  /// Cuánto se "puede gastar hoy": balance / días restantes del mes.
  final Decimal dailyBudget;

  /// Gasto del día de hoy (movimientos GASTO con fecha == hoy real).
  final Decimal todayExpenses;

  /// Proyección de balance a fin de mes extrapolando el ritmo de gasto.
  final Decimal projectedEndOfMonth;

  /// Patrimonio neto del hogar (assets − liabilities).
  final NetWorthBreakdown netWorth;

  /// Próximos vencimientos (ventana de 14 días, pendientes).
  final List<Bill> upcomingBills;

  /// Cantidad de vencimientos URGENTES (vencidos / hoy / en ≤3 días).
  final int urgentBillsCount;

  /// Metas de ahorro activas.
  final List<Goal> activeGoals;

  /// Planes de cuotas activos.
  final List<InstallmentPlan> activePlans;

  /// Semáforo de presupuesto: envelopes con asignación > 0.
  final List<BudgetSemaphoreItem> budgetSemaphore;

  /// Balance del período = ingresos − gastos.
  Decimal get balance => totalIngresos - totalGastos;

  /// `true` si no hay NINGÚN dato para mostrar (mes sin movimientos ni cuentas
  /// ni metas/bills/cuotas). Lo usa la UI para un empty-state general.
  bool get isEmpty =>
      totalIngresos == Decimal.zero &&
      totalGastos == Decimal.zero &&
      topCategories.isEmpty &&
      netWorth.perAccount.isEmpty &&
      upcomingBills.isEmpty &&
      activeGoals.isEmpty &&
      activePlans.isEmpty &&
      budgetSemaphore.isEmpty;
}

/// Controller del Home. `AsyncNotifier` que observa el hogar activo y el período
/// visible, y recomputa [HomeState] cuando cambia cualquiera de los dos.
///
/// Espejo de `HomeViewModel.load(householdId:)` de iOS: fetch en paralelo de
/// movimientos del período, cuentas, bills (14d), metas activas, planes de
/// cuotas activos, deudas y el período+allocations del presupuesto; y cómputo de
/// cada cifra con las MISMAS fórmulas, todo en [Decimal].
class HomeController extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    // El controller depende del hogar activo y del período visible. Observamos
    // ambos: cualquier cambio (switch de hogar, navegación de mes) reconstruye.
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    final YearMonth period = ref.watch(currentPeriodProvider);

    if (householdId == null) {
      // Sin hogar no hay nada que computar (el gate ya cubre el flujo de alta).
      return HomeState.empty();
    }

    return _load(
        householdId: householdId, year: period.year, month: period.month);
  }

  /// Carga + cómputo de todas las cifras del dashboard. Replica el orden y la
  /// matemática del `HomeViewModel.load` de iOS.
  Future<HomeState> _load({
    required String householdId,
    required int year,
    required int month,
  }) async {
    final txRepo = ref.read(transactionRepositoryProvider);
    final accountRepo = ref.read(accountRepositoryProvider);
    final billRepo = ref.read(billRepositoryProvider);
    final goalRepo = ref.read(goalRepositoryProvider);
    final planRepo = ref.read(installmentRepositoryProvider);
    final debtRepo = ref.read(debtRepositoryProvider);
    final budgetRepo = ref.read(budgetRepositoryProvider);

    // Ventana de 365 días hacia atrás (desde hoy real) para el running balance
    // del net worth — igual que iOS (`yearAgo … now`).
    final DateTime now = DateTime.now();
    final DateTime yearAgo = now.subtract(const Duration(days: 365));

    // Fetch en paralelo (espejo de los `async let` de iOS). Cada `catchError`
    // degrada con valor vacío para no tumbar todo el dashboard si una entidad
    // secundaria falla (mismo criterio de los `try?` de iOS).
    final Future<List<Transaction>> periodTxsF = txRepo.fetchForPeriod(
        householdId: householdId, year: year, month: month);
    final Future<List<Account>> accountsF =
        accountRepo.fetchAll(householdId).catchError((_) => <Account>[]);
    final Future<List<Transaction>> yearTxsF = txRepo
        .fetchRange(
            householdId: householdId, from: yearAgo, to: now, limit: 10000)
        .catchError((_) => <Transaction>[]);
    final Future<List<Bill>> billsF = billRepo
        .fetchUpcoming(householdId: householdId, daysAhead: 14)
        .catchError((_) => <Bill>[]);
    final Future<List<Goal>> goalsF = goalRepo
        .fetchAll(householdId: householdId, includeCompleted: false)
        .catchError((_) => <Goal>[]);
    final Future<List<InstallmentPlan>> plansF = planRepo
        .fetchPlans(householdId: householdId, includeCompleted: false)
        .catchError((_) => <InstallmentPlan>[]);
    final Future<List<Debt>> debtsF = debtRepo
        .fetchAll(householdId: householdId, includeSettled: false)
        .catchError((_) => <Debt>[]);

    final List<Transaction> periodTxs = await periodTxsF;
    final List<Account> accounts = await accountsF;
    final List<Transaction> yearTxs = await yearTxsF;
    final List<Bill> upcomingBills = await billsF;
    final List<Goal> activeGoals = await goalsF;
    final List<InstallmentPlan> activePlans = await plansF;
    final List<Debt> debts = await debtsF;

    // ── Totales del período (flujo) ────────────────────────────────────────
    // iOS: `ingresos = Σ amount(INGRESO)`, `gastos = Σ amount(GASTO)`. Sumamos
    // `amountInBase` (== amount con el contrato actual) para ser explícitos.
    var totalIngresos = Decimal.zero;
    var totalGastos = Decimal.zero;
    for (final Transaction tx in periodTxs) {
      switch (tx.type) {
        case TxType.ingreso:
          totalIngresos += tx.amountInBase;
        case TxType.gasto:
          totalGastos += tx.amountInBase;
      }
    }

    // ── Top categorías de gasto ────────────────────────────────────────────
    // iOS: agrupa GASTO por `category`, suma, ordena desc, toma prefix(5).
    final Map<String, Decimal> byCategory = <String, Decimal>{};
    for (final Transaction tx in periodTxs) {
      if (tx.type != TxType.gasto) continue;
      byCategory[tx.category] =
          (byCategory[tx.category] ?? Decimal.zero) + tx.amountInBase;
    }
    final List<CategoryTotal> topCategories = byCategory.entries
        .map((e) => CategoryTotal(category: e.key, total: e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final List<CategoryTotal> top5 = topCategories.take(5).toList();

    // ── Daily budget + gasto de hoy ────────────────────────────────────────
    // iOS: `dailyBudget = (ingresos − gastos) / max(daysInMonth − today.day + 1, 1)`
    // usando el DÍA REAL de hoy (no el del período navegado). `todayExpenses` =
    // Σ GASTO con fecha == hoy.
    final int daysInMonth = _daysInMonth(now.year, now.month);
    final int remainingDays =
        (daysInMonth - now.day + 1) < 1 ? 1 : (daysInMonth - now.day + 1);
    final Decimal balance = totalIngresos - totalGastos;
    final Decimal dailyBudget = (balance / Decimal.fromInt(remainingDays))
        .toDecimal(scaleOnInfinitePrecision: 4);

    var todayExpenses = Decimal.zero;
    for (final Transaction tx in periodTxs) {
      if (tx.type != TxType.gasto) continue;
      if (_isSameDay(tx.date, now)) todayExpenses += tx.amountInBase;
    }

    // ── Proyección a fin de mes ────────────────────────────────────────────
    // iOS: `projectedEndOfMonth = ingresos − (gastos / today.day * daysInMonth)`.
    // Si hoy es el día 0 (imposible: .day ≥ 1) protegemos contra div/0.
    final int todayDay = now.day < 1 ? 1 : now.day;
    final Decimal projectedSpend = (totalGastos / Decimal.fromInt(todayDay))
            .toDecimal(scaleOnInfinitePrecision: 6) *
        Decimal.fromInt(daysInMonth);
    final Decimal projectedEndOfMonth = totalIngresos - projectedSpend;

    // ── Net worth ──────────────────────────────────────────────────────────
    // iOS: `AccountBalanceService.netWorth(accounts, yearTxs, debts)`.
    final NetWorthBreakdown netWorth = BalanceCalculator.netWorth(
      accounts: accounts,
      transactions: yearTxs,
      debts: debts,
    );

    // ── Semáforo de presupuesto ────────────────────────────────────────────
    // Para cada envelope con `allocated > 0`, computamos lo gastado en su
    // categoría DENTRO del período visible (mismo criterio que la fórmula de
    // `envelope_balance`: GASTO por categoría + subcategoría dentro del rango).
    // Acá lo hacemos en memoria sobre `periodTxs` (rápido y suficiente para el
    // dashboard; la fuente canónica del saldo sigue siendo la RPC SQL).
    final List<BudgetSemaphoreItem> budgetSemaphore = await _computeSemaphore(
      budgetRepo: budgetRepo,
      householdId: householdId,
      year: year,
      month: month,
      periodTxs: periodTxs,
    );

    // ── Urgent bills ───────────────────────────────────────────────────────
    // iOS: cuenta bills con urgency overdue/dueToday/dueSoon.
    final int urgentBillsCount = upcomingBills
        .where((Bill b) =>
            b.urgency == BillUrgencyLevel.overdue ||
            b.urgency == BillUrgencyLevel.dueToday ||
            b.urgency == BillUrgencyLevel.dueSoon)
        .length;

    return HomeState(
      totalIngresos: totalIngresos,
      totalGastos: totalGastos,
      topCategories: top5,
      dailyBudget: dailyBudget,
      todayExpenses: todayExpenses,
      projectedEndOfMonth: projectedEndOfMonth,
      netWorth: netWorth,
      upcomingBills: upcomingBills,
      urgentBillsCount: urgentBillsCount,
      activeGoals: activeGoals,
      activePlans: activePlans,
      budgetSemaphore: budgetSemaphore,
    );
  }

  /// Construye el semáforo: asegura el período de presupuesto del mes, trae sus
  /// allocations y, por cada categoría con asignación > 0, agrega lo gastado en
  /// `periodTxs`. Degrada a lista vacía si el módulo de presupuesto falla
  /// (mismo espíritu que los `try?` de iOS).
  Future<List<BudgetSemaphoreItem>> _computeSemaphore({
    required BudgetRepository budgetRepo,
    required String householdId,
    required int year,
    required int month,
    required List<Transaction> periodTxs,
  }) async {
    try {
      final BudgetPeriod period = await budgetRepo.ensurePeriodForMonth(
        householdId: householdId,
        year: year,
        month: month,
      );
      final List<BudgetAllocation> allocations =
          await budgetRepo.fetchAllocations(period.id);

      // Gasto por categoría dentro del período (suma de subcategorías incluida).
      final Map<String, Decimal> spentByCategory = <String, Decimal>{};
      for (final Transaction tx in periodTxs) {
        if (tx.type != TxType.gasto) continue;
        spentByCategory[tx.category] =
            (spentByCategory[tx.category] ?? Decimal.zero) + tx.amountInBase;
      }

      // Asignado por categoría (sumando todas sus subcategorías) — el semáforo
      // del Home razona a nivel categoría, no subcategoría.
      final Map<String, Decimal> allocatedByCategory = <String, Decimal>{};
      for (final BudgetAllocation a in allocations) {
        allocatedByCategory[a.category] =
            (allocatedByCategory[a.category] ?? Decimal.zero) + a.allocated;
      }

      final List<BudgetSemaphoreItem> items = allocatedByCategory.entries
          .where((e) => e.value > Decimal.zero)
          .map((e) => BudgetSemaphoreItem(
                category: e.key,
                allocated: e.value,
                spent: spentByCategory[e.key] ?? Decimal.zero,
              ))
          .toList()
        // Más urgentes primero (mayor % usado arriba).
        ..sort((a, b) => b.rawPercentUsed.compareTo(a.rawPercentUsed));
      return items;
    } catch (_) {
      return const <BudgetSemaphoreItem>[];
    }
  }

  /// Fuerza una recarga del dashboard (pull-to-refresh). Mantiene visible el
  /// dato previo mientras recomputa (`AsyncValue.guard` setea loading→data).
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    final YearMonth period = ref.read(currentPeriodProvider);
    if (householdId == null) {
      state = AsyncData(HomeState.empty());
      return;
    }
    state = const AsyncLoading<HomeState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(
          householdId: householdId,
          year: period.year,
          month: period.month,
        ));
  }

  /// Días del mes [year]/[month] (maneja años bisiestos vía día 0 del mes+1).
  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// `true` si [a] y [b] caen en el mismo día calendario (local).
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Provider del controller del Home. `AsyncNotifierProvider` (no family):
/// el controller observa `currentHouseholdProvider` + `currentPeriodProvider`
/// internamente, así que invalida/reconstruye solo cuando cambian.
final homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeState>(HomeController.new);
