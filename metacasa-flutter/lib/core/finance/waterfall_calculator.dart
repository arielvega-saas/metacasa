import 'package:decimal/decimal.dart';

import '../../models/models.dart';

/// Motor de cálculo del presupuesto **Waterfall** (cascada) multi-persona.
///
/// Port 1:1 de `WaterfallCalculator.calculate()` de iOS
/// (`Core/WaterfallCalculator.swift`), que a su vez porta la lógica del web
/// (App.jsx:6245-6307):
///
/// ```
/// Ingresos del hogar (suma de INGRESO de todas las cuentas)
///   −  Gastos fijos mensuales (recurring_transactions GASTO frequency=monthly)
///   −  Vencimientos (bills pendientes del mes) [opcional]
///   −  Cuotas (installment_payments del mes) [opcional]
///   −  Pagos de deuda (debts.monthly_payment de deudas activas) [opcional]
///   −  Presupuesto de categorías compartidas (allocations en shared accounts)
///   −  % Ahorro (sobre el sub-total pre-distribución)
///   −  % Inversión (sobre el sub-total pre-distribución)
///   = Remanente
/// ```
///
/// El remanente se distribuye entre las cuentas PERSONALES según
/// `strategy.distributionMode`:
///   - equal: remanente ÷ N cuentas personales
///   - proportional: cada cuenta recibe según su proporción de ingreso
///     (fallback a equal si no hay ingresos identificados por cuenta)
///   - custom: cada cuenta recibe el monto definido manualmente
///
/// Todos los montos en [Decimal] (precisión exacta, nunca `double`).
class WaterfallCalculator {
  WaterfallCalculator({
    required this.transactions,
    required this.accounts,
    required this.fixedExpenses,
    required this.bills,
    required this.installmentPayments,
    required this.debts,
    required this.sharedAllocations,
    required this.strategy,
  });

  /// Movimientos del período (se usan los INGRESO).
  final List<Transaction> transactions;

  /// Cuentas del hogar (se filtran personales activas para distribuir).
  final List<Account> accounts;

  /// Recurrentes activas tipo GASTO frecuencia mensual (gastos fijos).
  final List<RecurringTransaction> fixedExpenses;

  /// Vencimientos del mes (se suman los pendientes).
  final List<Bill> bills;

  /// Cuotas del mes como pares (plan, payment) — espejo de la tupla iOS.
  final List<InstallmentPaymentRef> installmentPayments;

  /// Deudas (se suma `monthlyPayment` de las activas).
  final List<Debt> debts;

  /// Allocations de cuentas compartidas (presupuesto común).
  final List<BudgetAllocation> sharedAllocations;

  /// Configuración waterfall del hogar (porcentajes + flags + modo).
  final HouseholdStrategy strategy;

  /// Ejecuta la cascada completa y devuelve el resultado.
  WaterfallResult calculate() {
    final Decimal income = _totalIncome();
    final Decimal fixed = _fixedDeduction();
    final Decimal billsDed =
        strategy.includeBillsInWaterfall ? _billsDeduction() : Decimal.zero;
    final Decimal instDed = strategy.includeInstallmentsInWaterfall
        ? _installmentsDeduction()
        : Decimal.zero;
    final Decimal debtDed = strategy.includeDebtPaymentsInWaterfall
        ? _debtPaymentsDeduction()
        : Decimal.zero;
    final Decimal sharedDed = _sharedBudgetsDeduction();

    final Decimal beforePct =
        income - fixed - billsDed - instDed - debtDed - sharedDed;
    final Decimal savings = _pct(beforePct, strategy.savingsPct);
    final Decimal investment = _pct(beforePct, strategy.investmentPct);
    final Decimal remainder = beforePct - savings - investment;

    final List<AccountAllocation> dist = _distribute(remainder);

    return WaterfallResult(
      totalIncome: income,
      fixedDeduction: fixed,
      billsDeduction: billsDed,
      installmentsDeduction: instDed,
      debtPaymentsDeduction: debtDed,
      sharedBudgetsDeduction: sharedDed,
      savingsAllocation: savings,
      investmentAllocation: investment,
      remainder: remainder,
      distribution: dist,
    );
  }

  // MARK: - Cálculos individuales

  Decimal _totalIncome() => transactions.excludingTransfers
      .where((Transaction t) => t.type == TxType.ingreso)
      .fold(Decimal.zero, (Decimal acc, Transaction t) => acc + t.amount);

  Decimal _fixedDeduction() => fixedExpenses
      .where((RecurringTransaction r) =>
          r.active && r.type == TxType.gasto && r.frequency == Frequency.monthly)
      .fold(Decimal.zero, (Decimal acc, RecurringTransaction r) => acc + r.amount);

  Decimal _billsDeduction() => bills
      .where((Bill b) => b.status == BillStatus.pending)
      .fold(Decimal.zero, (Decimal acc, Bill b) => acc + b.amount);

  Decimal _installmentsDeduction() => installmentPayments
      .where((InstallmentPaymentRef p) => !p.payment.paid)
      .fold(Decimal.zero,
          (Decimal acc, InstallmentPaymentRef p) => acc + p.payment.amount);

  Decimal _debtPaymentsDeduction() => debts
      .where((Debt d) => d.status == DebtStatus.active)
      .map((Debt d) => d.monthlyPayment)
      .whereType<Decimal>()
      .fold(Decimal.zero, (Decimal acc, Decimal m) => acc + m);

  Decimal _sharedBudgetsDeduction() => sharedAllocations.fold(
      Decimal.zero, (Decimal acc, BudgetAllocation a) => acc + a.allocated);

  /// `base * pct / 100` con precisión exacta. La división por 100 es siempre
  /// terminante salvo arrastres de `base`; usamos scale alto por seguridad.
  Decimal _pct(Decimal base, Decimal pct) =>
      (base * pct / Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 10);

  /// Distribuye el remanente entre las cuentas personales activas según
  /// `strategy.distributionMode`. Espejo de `distribute(remainder:)` en iOS.
  List<AccountAllocation> _distribute(Decimal remainder) {
    final List<Account> personal = accounts
        .where((Account a) => a.ownership == AccountOwnership.personal && a.isActive)
        .toList();
    if (personal.isEmpty) return <AccountAllocation>[];

    switch (strategy.distributionMode) {
      case DistributionMode.equal:
        return _equalSplit(personal, remainder);

      case DistributionMode.proportional:
        // Ingreso identificado por cada cuenta personal (txs INGRESO con
        // account_id apuntando a la cuenta).
        final Map<String, Decimal> incomeByAccount = <String, Decimal>{};
        for (final Transaction tx in transactions) {
          if (tx.type != TxType.ingreso) continue;
          final String? aid = tx.accountId;
          if (aid == null) continue;
          incomeByAccount[aid] = (incomeByAccount[aid] ?? Decimal.zero) + tx.amount;
        }
        final Decimal totalPersonalIncome = personal.fold(
          Decimal.zero,
          (Decimal sum, Account acc) =>
              sum + (incomeByAccount[acc.id] ?? Decimal.zero),
        );
        if (totalPersonalIncome == Decimal.zero) {
          // Fallback a equal si no hay ingresos por cuenta (igual que iOS).
          return _equalSplit(personal, remainder);
        }
        return personal.map((Account acc) {
          final Decimal accIncome = incomeByAccount[acc.id] ?? Decimal.zero;
          final Decimal share = (remainder * accIncome / totalPersonalIncome)
              .toDecimal(scaleOnInfinitePrecision: 10);
          return AccountAllocation(
            accountId: acc.id,
            account: acc,
            amount: share,
            incomeSource: accIncome,
          );
        }).toList();

      case DistributionMode.custom:
        return personal.map((Account acc) {
          final Decimal custom = strategy.customAllocations[acc.id] ?? Decimal.zero;
          return AccountAllocation(
            accountId: acc.id,
            account: acc,
            amount: custom,
            incomeSource: Decimal.zero,
          );
        }).toList();
    }
  }

  /// Reparto equitativo: `remanente ÷ N`. La división puede ser no terminante
  /// (ej. /3), por eso se materializa con scale alto.
  List<AccountAllocation> _equalSplit(List<Account> personal, Decimal remainder) {
    final Decimal perAccount = (remainder / Decimal.fromInt(personal.length))
        .toDecimal(scaleOnInfinitePrecision: 10);
    return personal
        .map((Account acc) => AccountAllocation(
              accountId: acc.id,
              account: acc,
              amount: perAccount,
              incomeSource: Decimal.zero,
            ))
        .toList();
  }
}

/// Par (plan, payment) consumido por el waterfall — espejo de la tupla
/// `(plan: InstallmentPlan, payment: InstallmentPayment)` de iOS. Lo produce
/// `InstallmentRepository.fetchPaymentsForMonth`.
class InstallmentPaymentRef {
  const InstallmentPaymentRef({required this.plan, required this.payment});

  final InstallmentPlan plan;
  final InstallmentPayment payment;
}

/// Resultado de la cascada. Espejo de `WaterfallCalculator.Result` en iOS.
class WaterfallResult {
  const WaterfallResult({
    required this.totalIncome,
    required this.fixedDeduction,
    required this.billsDeduction,
    required this.installmentsDeduction,
    required this.debtPaymentsDeduction,
    required this.sharedBudgetsDeduction,
    required this.savingsAllocation,
    required this.investmentAllocation,
    required this.remainder,
    required this.distribution,
  });

  final Decimal totalIncome;
  final Decimal fixedDeduction;
  final Decimal billsDeduction;
  final Decimal installmentsDeduction;
  final Decimal debtPaymentsDeduction;
  final Decimal sharedBudgetsDeduction;
  final Decimal savingsAllocation;
  final Decimal investmentAllocation;
  final Decimal remainder;
  final List<AccountAllocation> distribution;
}

/// Asignación del remanente a una cuenta personal. Espejo de
/// `WaterfallCalculator.AccountAllocation` en iOS.
class AccountAllocation {
  const AccountAllocation({
    required this.accountId,
    required this.account,
    required this.amount,
    required this.incomeSource,
  });

  final String accountId;
  final Account account;
  final Decimal amount;

  /// Si el modo es proporcional, el ingreso identificado desde esta cuenta.
  final Decimal incomeSource;
}
