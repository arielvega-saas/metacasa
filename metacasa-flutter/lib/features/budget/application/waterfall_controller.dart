import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance/waterfall_calculator.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/bill_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/household_repository.dart';
import '../../../data/repositories/installment_repository.dart';
import '../../../data/repositories/recurring_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Inputs crudos de la cascada waterfall para el período visible. Clase plana
/// (sin freezed/codegen). Espejo de los campos del `WaterfallViewModel` /
/// `PlanEditorViewModel` de iOS: las MISMAS entidades que alimentan el
/// `WaterfallCalculator`.
///
/// La `strategy` que viene acá es la del hogar (persistida). El editor de
/// estrategia (`StrategySheet`) clona esta strategy localmente y re-corre el
/// calculator en vivo sin tocar este estado hasta guardar.
class WaterfallInputs {
  const WaterfallInputs({
    required this.transactions,
    required this.accounts,
    required this.fixedExpenses,
    required this.bills,
    required this.installmentPayments,
    required this.debts,
    required this.sharedAllocations,
    required this.strategy,
    required this.currency,
  });

  /// Inputs vacíos (sin hogar): listas vacías + strategy estándar.
  factory WaterfallInputs.empty() => WaterfallInputs(
        transactions: const <Transaction>[],
        accounts: const <Account>[],
        fixedExpenses: const <RecurringTransaction>[],
        bills: const <Bill>[],
        installmentPayments: const <InstallmentPaymentRef>[],
        debts: const <Debt>[],
        sharedAllocations: const <BudgetAllocation>[],
        strategy: HouseholdStrategy.standard(),
        currency: 'USD',
      );

  final List<Transaction> transactions;
  final List<Account> accounts;
  final List<RecurringTransaction> fixedExpenses;
  final List<Bill> bills;
  final List<InstallmentPaymentRef> installmentPayments;
  final List<Debt> debts;
  final List<BudgetAllocation> sharedAllocations;

  /// Strategy persistida del hogar (config waterfall vigente).
  final HouseholdStrategy strategy;

  /// Moneda base del hogar.
  final String currency;

  /// Corre el [WaterfallCalculator] con [overrideStrategy] (o la del hogar si
  /// es null). El editor de estrategia usa el override para el preview en vivo.
  WaterfallResult calculate({HouseholdStrategy? overrideStrategy}) {
    return WaterfallCalculator(
      transactions: transactions,
      accounts: accounts,
      fixedExpenses: fixedExpenses,
      bills: bills,
      installmentPayments: installmentPayments,
      debts: debts,
      sharedAllocations: sharedAllocations,
      strategy: overrideStrategy ?? strategy,
    ).calculate();
  }

  /// Ingreso identificado por cuenta personal (txs INGRESO con account_id),
  /// ordenado desc. Espejo de `incomeByAccount` de la WaterfallBudgetView —
  /// alimenta el desglose "ingresos por cuenta" del income card.
  List<AccountIncome> get incomeByAccount {
    final Map<String, Decimal> byAccount = <String, Decimal>{};
    for (final Transaction tx in transactions) {
      if (tx.type != TxType.ingreso) continue;
      final String? aid = tx.accountId;
      if (aid == null) continue;
      byAccount[aid] = (byAccount[aid] ?? Decimal.zero) + tx.amount;
    }
    final Map<String, Account> accountById = <String, Account>{
      for (final Account a in accounts) a.id: a,
    };
    final List<AccountIncome> entries = <AccountIncome>[];
    for (final MapEntry<String, Decimal> e in byAccount.entries) {
      final Account? acc = accountById[e.key];
      if (acc == null) continue;
      entries.add(AccountIncome(account: acc, amount: e.value));
    }
    entries.sort(
        (AccountIncome a, AccountIncome b) => b.amount.compareTo(a.amount));
    return entries;
  }
}

/// Par (cuenta, ingreso identificado) para el desglose del income card.
class AccountIncome {
  const AccountIncome({required this.account, required this.amount});

  final Account account;
  final Decimal amount;
}

/// Controller de los inputs de la cascada. `AsyncNotifier` que observa el hogar
/// activo + el período visible y fetchea, en paralelo, todas las entidades que
/// alimentan el `WaterfallCalculator`.
///
/// Espejo de `WaterfallViewModel.load`:
///   - transacciones del período (rango [start, end] del mes)
///   - cuentas activas
///   - recurrentes activas (gastos fijos)
///   - bills del mes
///   - pagos de cuotas del mes (pares plan/payment)
///   - deudas no saldadas
///   - shared allocations = allocations del período del mes
///   - strategy del hogar
class WaterfallController extends AsyncNotifier<WaterfallInputs> {
  @override
  Future<WaterfallInputs> build() async {
    final Household? household =
        await ref.watch(currentHouseholdProvider.future);
    final YearMonth period = ref.watch(currentPeriodProvider);

    if (household == null) return WaterfallInputs.empty();

    return _load(household: household, year: period.year, month: period.month);
  }

  Future<WaterfallInputs> _load({
    required Household household,
    required int year,
    required int month,
  }) async {
    final TransactionRepository txRepo =
        ref.read(transactionRepositoryProvider);
    final AccountRepository accountRepo = ref.read(accountRepositoryProvider);
    final RecurringRepository recurringRepo =
        ref.read(recurringRepositoryProvider);
    final BillRepository billRepo = ref.read(billRepositoryProvider);
    final InstallmentRepository installmentRepo =
        ref.read(installmentRepositoryProvider);
    final DebtRepository debtRepo = ref.read(debtRepositoryProvider);
    final BudgetRepository budgetRepo = ref.read(budgetRepositoryProvider);

    final String hid = household.id;

    // Fetch en paralelo (espejo de los `async let` de iOS). Cada secundaria
    // degrada a vacío para no tumbar la pantalla entera (mismo espíritu que los
    // `try?` de iOS).
    final Future<List<Transaction>> txsF = txRepo
        .fetchForPeriod(householdId: hid, year: year, month: month)
        .catchError((_) => <Transaction>[]);
    final Future<List<Account>> accountsF =
        accountRepo.fetchAll(hid).catchError((_) => <Account>[]);
    final Future<List<RecurringTransaction>> recurringF = recurringRepo
        .fetchAll(householdId: hid)
        .catchError((_) => <RecurringTransaction>[]);
    final Future<List<Bill>> billsF = billRepo
        .fetchForMonth(householdId: hid, year: year, month: month)
        .catchError((_) => <Bill>[]);
    final Future<List<InstallmentPaymentRef>> paymentsF = installmentRepo
        .fetchPaymentsForMonth(householdId: hid, year: year, month: month)
        .catchError((_) => <InstallmentPaymentRef>[]);
    final Future<List<Debt>> debtsF = debtRepo
        .fetchAll(householdId: hid, includeSettled: false)
        .catchError((_) => <Debt>[]);

    final List<Transaction> transactions = await txsF;
    final List<Account> accounts = await accountsF;
    final List<RecurringTransaction> fixedExpenses = await recurringF;
    final List<Bill> bills = await billsF;
    final List<InstallmentPaymentRef> payments = await paymentsF;
    final List<Debt> debts = await debtsF;

    // Shared allocations = allocations del período del mes. Si el módulo de
    // presupuesto falla, degradamos a vacío.
    List<BudgetAllocation> sharedAllocations;
    try {
      final BudgetPeriod period = await budgetRepo.ensurePeriodForMonth(
        householdId: hid,
        year: year,
        month: month,
      );
      sharedAllocations = await budgetRepo.fetchAllocations(period.id);
    } catch (_) {
      sharedAllocations = const <BudgetAllocation>[];
    }

    return WaterfallInputs(
      transactions: transactions,
      accounts: accounts,
      fixedExpenses: fixedExpenses,
      bills: bills,
      installmentPayments: payments,
      debts: debts,
      sharedAllocations: sharedAllocations,
      strategy: household.strategy ?? HouseholdStrategy.standard(),
      currency: household.defaultCurrency,
    );
  }

  /// Persiste una nueva [HouseholdStrategy] en el hogar y refresca el hogar
  /// activo (para que toda la app vea el cambio). Espejo de `saveStrategy` en
  /// iOS (`HouseholdService.updateStrategy` + `loadHouseholds`).
  Future<void> saveStrategy(HouseholdStrategy strategy) async {
    final Household? household =
        await ref.read(currentHouseholdProvider.future);
    if (household == null) return;
    await ref
        .read(householdRepositoryProvider)
        .updateStrategy(household.id, strategy);
    // Invalida el hogar activo: el provider re-fetchea y, al cambiar su valor,
    // este controller (que lo observa) se reconstruye con la nueva strategy. El
    // hub de presupuesto también se recomputa (shared deduction, etc.).
    ref.invalidate(currentHouseholdProvider);
  }

  /// Pull-to-refresh: recarga los inputs manteniendo el dato previo visible.
  Future<void> refresh() async {
    final Household? household =
        await ref.read(currentHouseholdProvider.future);
    final YearMonth period = ref.read(currentPeriodProvider);
    if (household == null) {
      state = AsyncData<WaterfallInputs>(WaterfallInputs.empty());
      return;
    }
    state = const AsyncLoading<WaterfallInputs>().copyWithPrevious(state);
    state = await AsyncValue.guard<WaterfallInputs>(
      () => _load(
        household: household,
        year: period.year,
        month: period.month,
      ),
    );
  }
}

/// Provider del controller de inputs de la cascada.
final waterfallControllerProvider =
    AsyncNotifierProvider<WaterfallController, WaterfallInputs>(
        WaterfallController.new);
