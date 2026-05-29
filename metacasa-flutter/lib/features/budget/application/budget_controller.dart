import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';
import '../../notifications/notification_preferences.dart';
import '../../notifications/notification_service.dart';

/// Un envelope (allocation) con su `EnvelopeStatus` ya computado. Espejo 1:1 de
/// `BudgetHubViewModel.EnvelopeWithAllocation` de iOS: junta la fila
/// `BudgetAllocation` con el status (allocated/spent/remaining/%).
///
/// El `allocated` del status es el **budgeted** (allocated + rolloverFromPrev),
/// igual que iOS — la barra y el % razonan sobre el presupuesto efectivo.
class BudgetEnvelope {
  const BudgetEnvelope({required this.allocation, required this.status});

  final BudgetAllocation allocation;
  final EnvelopeStatus status;

  /// `id` estable = id de la allocation (para keys de lista).
  String get id => allocation.id;

  /// Categoría del envelope (atajo).
  String get category => status.category;

  /// Subcategoría del envelope (puede ser vacía).
  String get subcategory => status.subcategory;

  /// Presupuesto efectivo (allocated + rollover). `status.allocated`.
  Decimal get budgeted => status.allocated;

  /// Gastado en el envelope dentro del período.
  Decimal get spent => status.spent;

  /// Saldo restante (budgeted − spent). Puede ser negativo (sobregiro).
  Decimal get remaining => status.remaining;

  /// % usado clampeado a [0, 1] (para el ancho de la barra).
  double get percentUsed => status.percentUsed;

  /// % usado SIN clampear (para decidir el color del umbral: >0.95 / >0.80).
  double get rawPercentUsed {
    if (budgeted <= Decimal.zero) return 0;
    return spent.toDouble() / budgeted.toDouble();
  }

  /// `true` si hay sobregiro (gastó más que lo presupuestado).
  bool get isOverBudget => status.isOverBudget;

  /// `true` si tiene rollover activo (badge en la UI).
  bool get hasRollover => allocation.rolloverMode != RolloverMode.none;
}

/// Estado inmutable del hub de presupuesto. Clase plana (sin freezed/codegen,
/// por requerimiento) con todas las cifras ya computadas en [Decimal].
///
/// Espejo del `BudgetHubViewModel` de iOS: período + allocations + envelopes con
/// status + ingresos/gastos del mes, y los tres totales derivados
/// (assigned/spent/readyToAssign).
class BudgetState {
  const BudgetState({
    required this.period,
    required this.allocations,
    required this.envelopes,
    required this.monthIncome,
    required this.monthExpenses,
    required this.currency,
  });

  /// Estado vacío (sin hogar / sin período): listas vacías, todo en cero.
  factory BudgetState.empty() => const BudgetState(
        period: null,
        allocations: <BudgetAllocation>[],
        envelopes: <BudgetEnvelope>[],
        monthIncome: null,
        monthExpenses: null,
        currency: 'USD',
      );

  /// Período de presupuesto del mes visible (null en el estado vacío).
  final BudgetPeriod? period;

  /// Allocations crudas del período (para `usedCategories` del editor).
  final List<BudgetAllocation> allocations;

  /// Envelopes con status computado, ordenados por % usado desc (más urgentes
  /// arriba, igual que iOS).
  final List<BudgetEnvelope> envelopes;

  /// Ingresos del mes (Σ INGRESO del período). Privado para forzar getters
  /// con fallback a cero.
  final Decimal? monthIncome;

  /// Gastos del mes (Σ GASTO del período).
  final Decimal? monthExpenses;

  /// Moneda base del hogar (para formatear los montos).
  final String currency;

  /// Ingresos del mes (cero si no hay datos).
  Decimal get ingresos => monthIncome ?? Decimal.zero;

  /// Gastos del mes (cero si no hay datos).
  Decimal get gastos => monthExpenses ?? Decimal.zero;

  /// Total asignado = Σ (allocated + rolloverFromPrev) de todos los envelopes.
  /// Espejo de `BudgetHubViewModel.totalAssigned`.
  Decimal get totalAssigned => allocations.fold(
        Decimal.zero,
        (Decimal acc, BudgetAllocation a) =>
            acc + a.allocated + a.rolloverFromPrev,
      );

  /// Total gastado = Σ spent de cada envelope. Espejo de
  /// `BudgetHubViewModel.totalSpent`.
  Decimal get totalSpent => envelopes.fold(
        Decimal.zero,
        (Decimal acc, BudgetEnvelope e) => acc + e.spent,
      );

  /// Disponible para asignar = ingresos del mes − total asignado. Espejo de
  /// `BudgetHubViewModel.readyToAssign`. (El zero-based busca llevar esto a 0.)
  Decimal get readyToAssign => ingresos - totalAssigned;

  /// `true` si no hay ningún envelope configurado (empty-state del editor).
  bool get hasNoEnvelopes => envelopes.isEmpty;

  /// Categorías que YA tienen un envelope (para que el editor solo ofrezca las
  /// que faltan al crear). Espejo de `Set(allocations.map { $0.category })`.
  Set<String> get usedCategories =>
      allocations.map((BudgetAllocation a) => a.category).toSet();
}

/// Controller del hub de presupuesto. `AsyncNotifier` que observa el hogar
/// activo + el período visible y recomputa [BudgetState] cuando cambia alguno.
///
/// Espejo de `BudgetHubViewModel.load(householdId:)` de iOS:
///   1. `ensurePeriodForMonth` para el mes visible.
///   2. `fetchAllocations` del período.
///   3. `totals` (ingresos/gastos) sobre el rango [periodStart, periodEnd].
///   4. Por cada allocation: `budgeted = allocated + rollover`,
///      `remaining = envelopeBalance(RPC)`, `spent = budgeted − remaining`.
///   5. Ordena por % usado desc.
///
/// La matemática del spent es **canónica en SQL** (`envelope_balance`), igual
/// que iOS — no se reimplementa en cliente (ver IOS_AUDIT §2 / CLAUDE.md).
class BudgetController extends AsyncNotifier<BudgetState> {
  @override
  Future<BudgetState> build() async {
    final Household? household =
        await ref.watch(currentHouseholdProvider.future);
    final YearMonth period = ref.watch(currentPeriodProvider);

    if (household == null) return BudgetState.empty();

    return _load(household: household, year: period.year, month: period.month);
  }

  /// Carga + cómputo del hub. Replica el orden y la matemática del
  /// `BudgetHubViewModel.load` de iOS.
  Future<BudgetState> _load({
    required Household household,
    required int year,
    required int month,
  }) async {
    final BudgetRepository budgetRepo = ref.read(budgetRepositoryProvider);
    final TransactionRepository txRepo =
        ref.read(transactionRepositoryProvider);
    final String currency = household.defaultCurrency;

    // 1. Asegurar el período del mes (lo crea si no existe).
    final BudgetPeriod period = await budgetRepo.ensurePeriodForMonth(
      householdId: household.id,
      year: year,
      month: month,
    );

    // 2. Allocations del período.
    final List<BudgetAllocation> allocations =
        await budgetRepo.fetchAllocations(period.id);

    // 3. Totales ingresos/gastos del rango del período. `try?`-style: si falla
    //    degradamos a cero (mismo criterio que el `?? (0,0)` de iOS).
    TransactionTotals totals;
    try {
      totals = await txRepo.totals(
        householdId: household.id,
        from: period.periodStart,
        to: period.periodEnd,
      );
    } catch (_) {
      totals = TransactionTotals.zero;
    }

    // 4. Status de cada envelope vía la RPC canónica `envelope_balance`.
    //    `budgeted = allocated + rolloverFromPrev`; `remaining` lo da la RPC
    //    (fallback a `budgeted` si la RPC falla, igual que iOS); `spent =
    //    budgeted − remaining`.
    final List<BudgetEnvelope> envelopes = <BudgetEnvelope>[];
    for (final BudgetAllocation a in allocations) {
      final Decimal budgeted = a.allocated + a.rolloverFromPrev;
      Decimal remaining;
      try {
        remaining = await budgetRepo.envelopeBalance(
          period.id,
          a.category,
          a.subcategory,
        );
      } catch (_) {
        remaining = budgeted;
      }
      final Decimal spent = budgeted - remaining;
      envelopes.add(
        BudgetEnvelope(
          allocation: a,
          status: EnvelopeStatus(
            category: a.category,
            subcategory: a.subcategory,
            allocated: budgeted,
            spent: spent,
          ),
        ),
      );
    }

    // 5. Orden por % usado desc (más urgentes primero).
    envelopes.sort(
      (BudgetEnvelope x, BudgetEnvelope y) =>
          y.status.percentUsed.compareTo(x.status.percentUsed),
    );

    // 6. Avisos de envelope-overspend (fire-and-forget, guardado). Se invoca en
    //    cada build; la dedupe por id (categoría+mes+umbral) en el servicio evita
    //    repetir el mismo aviso. `period.periodStart` da la clave de mes.
    unawaited(
      _notifyOverspend(
        envelopes: envelopes,
        periodStart: period.periodStart,
        currency: currency,
      ),
    );

    return BudgetState(
      period: period,
      allocations: allocations,
      envelopes: envelopes,
      monthIncome: totals.ingresos,
      monthExpenses: totals.gastos,
      currency: currency,
    );
  }

  /// Recorre los envelopes y dispara una notif inmediata por cada uno que cruce
  /// un umbral (80/100/120 %). Best-effort: inicializa el servicio perezosamente
  /// y, si algo falla, sigue. La dedupe persistente del servicio garantiza un
  /// aviso por (categoría, mes, umbral); usamos `rawPercentUsed` (sin clampear)
  /// para detectar el sobregiro >100 %. Nunca lanza.
  Future<void> _notifyOverspend({
    required List<BudgetEnvelope> envelopes,
    required DateTime periodStart,
    required String currency,
  }) async {
    try {
      final NotificationService svc = ref.read(notificationServiceProvider);
      await svc.init();
      if (!svc.isReady) return;
      final NotificationPreferences prefs =
          ref.read(notificationPreferencesProvider);
      if (!prefs.envelopeOverspend) return;
      for (final BudgetEnvelope e in envelopes) {
        if (e.budgeted <= Decimal.zero) continue; // sin presupuesto: sin %
        if (e.rawPercentUsed < 0.80) continue;
        await svc.notifyEnvelopeOverspend(
          category: e.category,
          subcategory: e.subcategory.isEmpty ? null : e.subcategory,
          period: periodStart,
          percentUsed: e.rawPercentUsed,
          allocated: e.budgeted,
          spent: e.spent,
          currencyCode: currency,
          prefs: prefs,
        );
      }
    } catch (_) {
      // Sin notificaciones disponibles (p. ej. test/desktop): no-op.
    }
  }

  /// Crea o actualiza un envelope (allocation), y si cambió el rollover mode lo
  /// persiste con la mutación dedicada. Recarga el hub al terminar. Espejo de
  /// `BudgetHubViewModel.upsert`.
  Future<void> upsertEnvelope({
    required String category,
    required String subcategory,
    required Decimal allocated,
    required RolloverMode rolloverMode,
  }) async {
    final BudgetPeriod? period = state.valueOrNull?.period;
    if (period == null) return;
    final BudgetRepository budgetRepo = ref.read(budgetRepositoryProvider);
    final String currency = state.valueOrNull?.currency ?? 'USD';

    final BudgetAllocation saved = await budgetRepo.upsertAllocation(
      periodId: period.id,
      category: category,
      subcategory: subcategory,
      allocated: allocated,
      currency: currency,
    );
    if (saved.rolloverMode != rolloverMode) {
      await budgetRepo.updateRolloverMode(
        allocationId: saved.id,
        mode: rolloverMode,
      );
    }
    await refresh();
  }

  /// Elimina un envelope y recarga. Espejo de `BudgetHubViewModel.delete`.
  Future<void> deleteEnvelope(String allocationId) async {
    final BudgetRepository budgetRepo = ref.read(budgetRepositoryProvider);
    await budgetRepo.deleteAllocation(allocationId);
    await refresh();
  }

  /// Fuerza una recarga del hub (pull-to-refresh / post-mutación). Mantiene el
  /// dato previo visible mientras recomputa.
  Future<void> refresh() async {
    final Household? household =
        await ref.read(currentHouseholdProvider.future);
    final YearMonth period = ref.read(currentPeriodProvider);
    if (household == null) {
      state = AsyncData<BudgetState>(BudgetState.empty());
      return;
    }
    state = const AsyncLoading<BudgetState>().copyWithPrevious(state);
    state = await AsyncValue.guard<BudgetState>(
      () => _load(
        household: household,
        year: period.year,
        month: period.month,
      ),
    );
  }
}

/// Provider del controller del hub de presupuesto. `AsyncNotifierProvider`
/// (no family): observa hogar + período internamente.
final budgetControllerProvider =
    AsyncNotifierProvider<BudgetController, BudgetState>(BudgetController.new);
