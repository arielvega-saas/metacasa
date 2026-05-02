import Foundation

/// Servicio que calcula el balance actual de cada cuenta aplicando todas
/// las transacciones sobre el `startingBalance`, y el patrimonio neto
/// (net worth) del hogar = assets - liabilities.
///
/// Convenciones:
/// - Para cuentas tipo `checking`/`savings`/`cash`/`investment`/`other`:
///   gastos restan, ingresos suman.
/// - Para `creditCard` y `loan`: si el balance resultante es negativo,
///   se trata como **liability** (deuda con magnitud). Si es positivo
///   (raro — p.ej. overpayment), suma como asset.
/// - Las `debts` (tabla separada) se suman enteras como liability usando
///   `currentBalance` del modelo `Debt`.
///
/// Todo en memoria — no hace requests. Se pasa `[Transaction]` ya fetcheadas
/// por el caller (normalmente HomeViewModel o NetWorthWidget).
@MainActor
enum AccountBalanceService {

    /// Balance actual de una cuenta tras aplicar todas las transacciones
    /// que la referencian. Si la transacción no tiene `accountId`, no la
    /// considera (quedó "del hogar").
    static func currentBalance(
        account: Account,
        transactions: [Transaction]
    ) -> Decimal {
        let accountTxs = transactions.filter { $0.accountId == account.id }
        let delta = accountTxs.reduce(Decimal(0)) { acc, tx in
            tx.type == .gasto ? acc - tx.amount : acc + tx.amount
        }
        return account.startingBalance + delta
    }

    /// Calcula patrimonio neto = assets - liabilities para todo el hogar.
    /// Segmenta el desglose para que la UI pueda mostrar 2 líneas + total.
    static func netWorth(
        accounts: [Account],
        transactions: [Transaction],
        debts: [Debt]
    ) -> NetWorthBreakdown {
        var assets: Decimal = 0
        var liabilities: Decimal = 0
        var perAccount: [AccountBalance] = []

        for account in accounts where account.isActive {
            let balance = currentBalance(account: account, transactions: transactions)
            perAccount.append(.init(account: account, balance: balance))

            switch account.type {
            case .checking, .savings, .cash, .investment, .other:
                // Tipo asset: el balance va directo a assets (aunque sea
                // negativo, lo cual sería inusual pero informativo).
                assets += balance
            case .creditCard, .loan:
                // Tipo liability: convención: negativo = deuda pendiente,
                // positivo = overpayment (sumaría a assets).
                if balance < 0 {
                    liabilities += abs(balance)
                } else {
                    assets += balance
                }
            }
        }

        for debt in debts where debt.currentBalance > 0 {
            liabilities += debt.currentBalance
        }

        return NetWorthBreakdown(
            assets: assets,
            liabilities: liabilities,
            perAccount: perAccount
        )
    }
}

// MARK: - Models

/// Desglose de patrimonio neto. `netWorth` es propiedad derivada.
struct NetWorthBreakdown: Sendable, Equatable {
    let assets: Decimal
    let liabilities: Decimal
    let perAccount: [AccountBalance]

    var netWorth: Decimal { assets - liabilities }

    /// Ratio de liabilities sobre total de obligaciones + assets. 0-1.
    /// Útil para indicadores de "solvencia": <0.3 sano, >0.6 alerta.
    var debtToAssetRatio: Double {
        let total = (assets as NSDecimalNumber).doubleValue
        let liab = (liabilities as NSDecimalNumber).doubleValue
        guard total > 0 else { return liab > 0 ? 1.0 : 0 }
        return min(1.0, max(0, liab / total))
    }

    static let zero = NetWorthBreakdown(assets: 0, liabilities: 0, perAccount: [])
}

/// Balance puntual de una cuenta (post-aplicación de transacciones).
struct AccountBalance: Sendable, Equatable {
    let account: Account
    let balance: Decimal
}
