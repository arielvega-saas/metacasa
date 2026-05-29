import 'package:decimal/decimal.dart';

import '../../models/models.dart';

/// Helper de monto en moneda base del hogar.
///
/// La columna `fx_rate_to_base` define cuántas unidades base equivalen a 1
/// unidad de la moneda original; `amount` YA viene convertido a base
/// server-side (default `fx_rate_to_base = 1`). Por eso el cálculo de balance
/// usa `amount` tal cual (igual que `AccountBalanceService` en iOS, que NO
/// reconvierte). Exponemos [amountInBase] solo como utilidad explícita para
/// callers que tengan `amount` en moneda original: `amount * (fxRateToBase ?? 1)`.
extension TransactionBaseAmount on Transaction {
  /// `amount * (fxRateToBase ?? 1)`. NOTA: con el contrato actual `amount` ya
  /// está en base, así que esto coincide con `amount` salvo que el caller
  /// haya cargado el monto original sin convertir.
  Decimal get amountInBase => amount * (fxRateToBase ?? Decimal.one);
}

/// Calculadora pura (sin red) de balances de cuenta y patrimonio neto.
///
/// Port 1:1 de `AccountBalanceService.swift`. Recibe `[Transaction]` ya
/// fetcheadas por el caller y opera todo en memoria con [Decimal].
///
/// Convenciones (idénticas a iOS):
/// - checking/savings/cash/investment/other → el balance suma a `assets`.
/// - credit_card/loan → si el balance es negativo es `liability` (con
///   magnitud absoluta); si es positivo (overpayment) suma a `assets`.
/// - debts (tabla aparte) con `currentBalance > 0` suman a `liabilities`.
abstract final class BalanceCalculator {
  const BalanceCalculator._();

  /// Balance actual de una cuenta = `startingBalance + Σ(amount con signo)`,
  /// sobre las transacciones que la referencian (`tx.accountId == account.id`).
  /// Gasto resta, ingreso suma. Las txs sin `accountId` (del hogar) se ignoran.
  /// Port de `AccountBalanceService.currentBalance`.
  static Decimal currentBalance(
    Account account,
    List<Transaction> transactions,
  ) {
    var delta = Decimal.zero;
    for (final Transaction tx in transactions) {
      if (tx.accountId != account.id) continue;
      switch (tx.type) {
        case TxType.gasto:
          delta -= tx.amount;
        case TxType.ingreso:
          delta += tx.amount;
      }
    }
    return account.startingBalance + delta;
  }

  /// Patrimonio neto = assets − liabilities para todo el hogar. Devuelve el
  /// desglose ([NetWorthBreakdown]) con el balance por cuenta. Solo considera
  /// cuentas activas (`isActive`). Port de `AccountBalanceService.netWorth`.
  static NetWorthBreakdown netWorth({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<Debt> debts,
  }) {
    var assets = Decimal.zero;
    var liabilities = Decimal.zero;
    final List<AccountBalance> perAccount = <AccountBalance>[];

    for (final Account account in accounts) {
      if (!account.isActive) continue;
      final Decimal balance = currentBalance(account, transactions);
      perAccount.add(AccountBalance(account: account, balance: balance));

      switch (account.type) {
        case AccountType.checking:
        case AccountType.savings:
        case AccountType.cash:
        case AccountType.investment:
        case AccountType.other:
          // Tipo asset: el balance va directo a assets (aunque sea negativo).
          assets += balance;
        case AccountType.creditCard:
        case AccountType.loan:
          // Tipo liability: negativo = deuda pendiente (magnitud),
          // positivo = overpayment (suma a assets).
          if (balance < Decimal.zero) {
            liabilities += -balance; // abs(balance)
          } else {
            assets += balance;
          }
      }
    }

    for (final Debt debt in debts) {
      if (debt.currentBalance > Decimal.zero) {
        liabilities += debt.currentBalance;
      }
    }

    return NetWorthBreakdown(
      assets: assets,
      liabilities: liabilities,
      perAccount: perAccount,
    );
  }
}

/// Desglose de patrimonio neto. `netWorth` es derivado. Espejo de
/// `NetWorthBreakdown` en iOS.
class NetWorthBreakdown {
  const NetWorthBreakdown({
    required this.assets,
    required this.liabilities,
    required this.perAccount,
  });

  final Decimal assets;
  final Decimal liabilities;
  final List<AccountBalance> perAccount;

  /// Patrimonio neto = assets − liabilities.
  Decimal get netWorth => assets - liabilities;

  /// Ratio de liabilities sobre assets, acotado a 0–1. <0.3 sano, >0.6 alerta.
  /// Port de `debtToAssetRatio` en iOS (mantiene el mismo edge-case: si no hay
  /// assets pero sí deudas → 1.0).
  double get debtToAssetRatio {
    final double total = assets.toDouble();
    final double liab = liabilities.toDouble();
    if (total <= 0) return liab > 0 ? 1.0 : 0.0;
    return (liab / total).clamp(0.0, 1.0);
  }

  static final NetWorthBreakdown zero = NetWorthBreakdown(
    assets: Decimal.zero,
    liabilities: Decimal.zero,
    perAccount: const <AccountBalance>[],
  );
}

/// Balance puntual de una cuenta (post-aplicación de transacciones).
/// Espejo de `AccountBalance` en iOS.
class AccountBalance {
  const AccountBalance({required this.account, required this.balance});

  final Account account;
  final Decimal balance;
}
