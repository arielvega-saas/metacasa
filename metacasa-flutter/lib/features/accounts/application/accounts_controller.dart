import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance/balance_calculator.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Estado inmutable de la pantalla de Cuentas. Clase plana (sin freezed/codegen,
/// por requerimiento) con las cuentas activas, su balance vivo ya computado y el
/// desglose de patrimonio neto del hogar.
///
/// Espejo conceptual del `AccountsView` + `AccountBalanceService.netWorth` de
/// iOS: en iOS la lista muestra `startingBalance` plano, pero acá computamos el
/// balance REAL de cada cuenta (`startingBalance + Σ tx`) con las mismas
/// transacciones que alimentan el net worth, para que la lista y el header sean
/// coherentes y vivos.
class AccountsState {
  const AccountsState({
    required this.balances,
    required this.netWorth,
  });

  /// Estado vacío (sin hogar o sin cuentas): lista vacía + net worth en cero.
  factory AccountsState.empty() => AccountsState(
        balances: const <AccountBalance>[],
        netWorth: NetWorthBreakdown.zero,
      );

  /// Cuentas activas con su balance vivo, ordenadas por `display_order` (el
  /// repo ya las trae ordenadas; preservamos ese orden).
  final List<AccountBalance> balances;

  /// Patrimonio neto del hogar (assets − liabilities) con el desglose por
  /// cuenta. Incluye las deudas de la tabla `debts`.
  final NetWorthBreakdown netWorth;

  /// `true` si no hay ninguna cuenta para mostrar.
  bool get isEmpty => balances.isEmpty;

  /// Balance vivo de una cuenta puntual (helper para el detalle simple, que
  /// quiere mostrar el saldo computado sin recalcular).
  Decimal balanceFor(String accountId) {
    for (final AccountBalance b in balances) {
      if (b.account.id == accountId) return b.balance;
    }
    return Decimal.zero;
  }
}

/// Controller de la pantalla de Cuentas. `AsyncNotifier` que observa el hogar
/// activo y, ante cualquier cambio (switch de hogar), recomputa el [AccountsState].
///
/// Replica el fetch del `HomeController` para el net worth: cuentas + ventana de
/// 365 días de transacciones + deudas activas, todo en paralelo, y el cómputo
/// con `BalanceCalculator` (mismas fórmulas que iOS, en [Decimal]).
class AccountsController extends AsyncNotifier<AccountsState> {
  @override
  Future<AccountsState> build() async {
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      // Sin hogar no hay cuentas (el gate cubre el flujo de alta).
      return AccountsState.empty();
    }
    return _load(householdId);
  }

  /// Fetch + cómputo. Trae cuentas, la ventana anual de movimientos y las
  /// deudas activas en paralelo (espejo de los `async let` de iOS); luego arma
  /// el net worth y el balance vivo de cada cuenta.
  Future<AccountsState> _load(String householdId) async {
    final AccountRepository accountRepo = ref.read(accountRepositoryProvider);
    final TransactionRepository txRepo =
        ref.read(transactionRepositoryProvider);
    final DebtRepository debtRepo = ref.read(debtRepositoryProvider);

    // Ventana de 365 días hacia atrás (desde hoy real) para el running balance,
    // igual que el `HomeController` (`yearAgo … now`).
    final DateTime now = DateTime.now();
    final DateTime yearAgo = now.subtract(const Duration(days: 365));

    // `catchError` en las entidades secundarias degrada a vacío para no tumbar
    // la pantalla entera si una falla (mismo criterio que los `try?` de iOS).
    final Future<List<Account>> accountsF = accountRepo.fetchAll(householdId);
    final Future<List<Transaction>> txsF = txRepo
        .fetchRange(
            householdId: householdId, from: yearAgo, to: now, limit: 10000)
        .catchError((_) => <Transaction>[]);
    final Future<List<Debt>> debtsF = debtRepo
        .fetchAll(householdId: householdId, includeSettled: false)
        .catchError((_) => <Debt>[]);

    final List<Account> accounts = await accountsF;
    final List<Transaction> txs = await txsF;
    final List<Debt> debts = await debtsF;

    // Net worth = assets − liabilities, con el balance vivo por cuenta.
    // `BalanceCalculator.netWorth` ya filtra cuentas inactivas y arma el
    // `perAccount` con `currentBalance(account, txs)` cada una.
    final NetWorthBreakdown netWorth = BalanceCalculator.netWorth(
      accounts: accounts,
      transactions: txs,
      debts: debts,
    );

    // La lista respeta el orden de `fetchAll` (display_order). `perAccount` del
    // net worth no garantiza ese orden (saltea inactivas), así que reconstruimos
    // los balances recorriendo `accounts` y reusando el cómputo puro.
    final List<AccountBalance> balances = accounts
        .map((Account a) => AccountBalance(
              account: a,
              balance: BalanceCalculator.currentBalance(a, txs),
            ))
        .toList();

    return AccountsState(balances: balances, netWorth: netWorth);
  }

  /// Fuerza una recarga (pull-to-refresh / post-alta). Mantiene visible el dato
  /// previo mientras recomputa (`AsyncValue.guard` setea loading→data).
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      state = AsyncData(AccountsState.empty());
      return;
    }
    state = const AsyncLoading<AccountsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(householdId));
  }
}

/// Provider del controller de Cuentas. `AsyncNotifierProvider` (no family): el
/// controller observa `currentHouseholdProvider` internamente, así que se
/// reconstruye solo cuando cambia el hogar activo.
final accountsControllerProvider =
    AsyncNotifierProvider<AccountsController, AccountsState>(
        AccountsController.new);
