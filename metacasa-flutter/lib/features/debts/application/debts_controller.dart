import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Estado inmutable de la pantalla de Deudas: la lista de deudas + los agregados
/// del header (deuda total y pago mensual total). Clase plana (sin freezed/
/// codegen, por requerimiento), mismo criterio que `AccountsState`.
class DebtsState {
  const DebtsState({
    required this.debts,
    required this.totalBalance,
    required this.totalMonthly,
  });

  /// Estado vacío (sin hogar o sin deudas): lista vacía + agregados en cero.
  factory DebtsState.empty() => DebtsState(
        debts: const <Debt>[],
        totalBalance: Decimal.zero,
        totalMonthly: Decimal.zero,
      );

  /// Deudas del hogar (orden del repo: `created_at` desc).
  final List<Debt> debts;

  /// Suma de `currentBalance` de las deudas ACTIVAS — la deuda total viva.
  /// Espejo de `totalBalance` del `totalCard` de iOS.
  final Decimal totalBalance;

  /// Suma de `monthlyPayment` (cuando está definido) de las deudas ACTIVAS — el
  /// compromiso mensual de deuda. Espejo de `monthlyCommitment` de iOS.
  final Decimal totalMonthly;

  /// `true` si no hay ninguna deuda para mostrar.
  bool get isEmpty => debts.isEmpty;
}

/// Controller de la pantalla de Deudas. `AsyncNotifier` que observa el hogar
/// activo y, ante un cambio (switch de hogar), recarga las deudas y recomputa
/// los agregados.
///
/// Replica el `load()` + `totalCard` del `DebtsListView` de iOS: trae todas las
/// deudas (incluyendo saldadas, para el historial) y suma sobre las ACTIVAS el
/// saldo vivo y el pago mensual. Matemática en `Decimal` (exacta).
class DebtsController extends AsyncNotifier<DebtsState> {
  @override
  Future<DebtsState> build() async {
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      // Sin hogar no hay deudas (el gate cubre el alta de hogar).
      return DebtsState.empty();
    }
    return _load(householdId);
  }

  /// Fetch de deudas + cómputo de agregados.
  Future<DebtsState> _load(String householdId) async {
    // Incluimos saldadas para que el historial siga visible (igual que iOS,
    // que llama `fetchAll(householdId:)` con el default `includeSettled`).
    final List<Debt> debts = await ref
        .read(debtRepositoryProvider)
        .fetchAll(householdId: householdId);

    var totalBalance = Decimal.zero;
    var totalMonthly = Decimal.zero;
    for (final Debt d in debts) {
      if (d.status != DebtStatus.active) continue;
      totalBalance += d.currentBalance;
      final Decimal? monthly = d.monthlyPayment;
      if (monthly != null) totalMonthly += monthly;
    }

    return DebtsState(
      debts: debts,
      totalBalance: totalBalance,
      totalMonthly: totalMonthly,
    );
  }

  /// Crea una deuda y refresca la lista.
  Future<void> insert(Debt debt) async {
    await ref.read(debtRepositoryProvider).insert(debt);
    await refresh();
  }

  /// Actualiza una deuda existente y refresca. (Se llama `updateDebt` y no
  /// `update` para no chocar con el `AsyncNotifier.update` heredado.)
  Future<void> updateDebt(Debt debt) async {
    await ref.read(debtRepositoryProvider).update(debt);
    await refresh();
  }

  /// Salda una deuda (`status='settled'`, `current_balance=0`) y refresca.
  Future<void> settle(String id) async {
    await ref.read(debtRepositoryProvider).settle(id);
    await refresh();
  }

  /// Elimina una deuda y refresca.
  Future<void> delete(String id) async {
    await ref.read(debtRepositoryProvider).delete(id);
    await refresh();
  }

  /// Fuerza una recarga (pull-to-refresh / post-alta / post-edición). Mantiene
  /// visible el dato previo mientras recomputa.
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      state = AsyncData(DebtsState.empty());
      return;
    }
    state = const AsyncLoading<DebtsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(householdId));
  }
}

/// Provider del controller de Deudas. `AsyncNotifierProvider` (no family): el
/// controller observa `currentHouseholdProvider` internamente, así que se
/// reconstruye solo cuando cambia el hogar activo.
final debtsControllerProvider =
    AsyncNotifierProvider<DebtsController, DebtsState>(DebtsController.new);
