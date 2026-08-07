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
///
/// **Sin `@MainActor` a propósito**: es aritmética pura sobre valores, no toca
/// interfaz. Estaba anotado igual, y eso obligaba a que el cálculo corriera en
/// el hilo principal — incluido el del asistente, que recorre hasta 10.000
/// transacciones por cada cuenta. Las vistas lo siguen llamando sin cambios
/// (desde el main actor se puede invocar código no aislado); lo que cambia es
/// que ahora también puede llamarlo un `actor` de fondo sin arrastrar la UI.
enum AccountBalanceService {

    /// Balance actual de una cuenta, **en la moneda de esa cuenta**.
    ///
    /// `startingBalance` está en la moneda de la cuenta y `tx.amount` en la
    /// moneda BASE del hogar: sumarlos directo era sumar dólares con pesos. Una
    /// caja de ahorro en USD dentro de un hogar en ARS, con saldo inicial
    /// US$1.000 y un ingreso de US$500 a tasa 1000, daba `1.000 + 500.000` y la
    /// pantalla mostraba **US$ 501.000** en vez de US$1.500.
    ///
    /// Regla (idéntica a `saldoDeCuenta` en la web, `lib/db/account-balance.ts`):
    /// de cada movimiento se toma el monto en la moneda de la cuenta —
    /// `amountOriginal` cuando la moneda coincide, y si no, se convierte desde
    /// base con la tasa del hogar. Sin tasa se suma el monto en base: descartar
    /// el movimiento dejaría el saldo mal sin que nada lo indique.
    ///
    /// Si la transacción no tiene `accountId`, no se considera (quedó "del hogar").
    ///
    /// - Parameters:
    ///   - baseCurrency: moneda base del hogar, en la que está `tx.amount`.
    ///   - fxRates: tasas del hogar (moneda → tasa hacia base).
    static func currentBalance(
        account: Account,
        transactions: [Transaction],
        baseCurrency: String,
        fxRates: [String: FXRate] = [:]
    ) -> Decimal {
        let cuenta = account.currency.uppercased()
        let base = baseCurrency.uppercased()
        let accountTxs = transactions.filter { $0.accountId == account.id }

        let delta = accountTxs.reduce(Decimal(0)) { acc, tx in
            let monto = montoEnMonedaDeCuenta(
                tx, cuenta: cuenta, base: base, fxRates: fxRates
            )
            return tx.type == .gasto ? acc - monto : acc + monto
        }
        return account.startingBalance + delta
    }

    /// Monto de `tx` expresado en la moneda de la cuenta.
    private static func montoEnMonedaDeCuenta(
        _ tx: Transaction,
        cuenta: String,
        base: String,
        fxRates: [String: FXRate]
    ) -> Decimal {
        let original = (tx.currencyOriginal ?? base).uppercased()
        if original == cuenta, let amountOriginal = tx.amountOriginal {
            return amountOriginal
        }
        if cuenta == base { return tx.amount }
        // `amount` está en base y la tasa va de la moneda de la cuenta HACIA
        // base, así que para ir de base a la cuenta se divide.
        if let tasa = fxRates[cuenta]?.rate, tasa != 0 {
            return tx.amount / tasa
        }
        return tx.amount
    }

    /// Igual que `netWorth(accounts:transactions:debts:)` pero con los saldos ya
    /// calculados server-side (RPC `account_balances`) en vez de derivarlos de
    /// las transacciones en el device. Misma clasificación asset/liability.
    ///
    /// Una cuenta sin entrada en `balances` cae a su `startingBalance` (no
    /// debería pasar: el RPC devuelve todas las activas del hogar).
    /// - Parameters:
    ///   - baseCurrency: moneda base del hogar. Todo se convierte a ésta antes de sumar.
    ///   - fxRates: mapa de tasas del hogar. Una cuenta cuya moneda no tenga tasa se **omite**
    ///     del total y se marca en `hasUnconvertible`.
    ///
    /// Antes esta función sumaba `balance` sin mirar `account.currency`, así que una caja de
    /// ahorro en USD 5.000 y una cuenta corriente en ARS 300.000 daban "$305.000" — cuando el
    /// valor real ronda los $7.800.000. **Un error de 25× en la cifra más visible de la app.**
    /// Lo mismo pasaba con `debt.currentBalance`, que también tiene su propia moneda.
    ///
    /// El criterio de omitir-y-marcar (en vez de asumir tasa 1) es el que ya usa la web en
    /// `dashboard/page.tsx`: mostrar un total incompleto y avisarlo es honesto; mezclar monedas
    /// da un número con aspecto de correcto que no significa nada.
    static func netWorth(
        accounts: [Account],
        balances: [UUID: Decimal],
        debts: [Debt],
        baseCurrency: String,
        fxRates: FXRateMap
    ) -> NetWorthBreakdown {
        var assets: Decimal = 0
        var liabilities: Decimal = 0
        var perAccount: [AccountBalance] = []
        var hasUnconvertible = false

        for account in accounts where account.isActive {
            let balance = balances[account.id] ?? account.startingBalance
            // `perAccount` conserva el saldo en la moneda DE LA CUENTA: es lo que se muestra en
            // la lista de cuentas, etiquetado con `account.currency`. Sólo el agregado convierte.
            perAccount.append(.init(account: account, balance: balance))

            guard let converted = FXConverter.convert(
                balance, from: account.currency, to: baseCurrency, rates: fxRates
            ) else {
                hasUnconvertible = true
                continue
            }

            switch account.type {
            case .checking, .savings, .cash, .investment, .other:
                assets += converted
            case .creditCard, .loan:
                if converted < 0 {
                    liabilities += abs(converted)
                } else {
                    assets += converted
                }
            }
        }

        for debt in debts where debt.currentBalance > 0 {
            guard let converted = FXConverter.convert(
                debt.currentBalance, from: debt.currency, to: baseCurrency, rates: fxRates
            ) else {
                hasUnconvertible = true
                continue
            }
            liabilities += converted
        }

        return NetWorthBreakdown(
            assets: assets,
            liabilities: liabilities,
            perAccount: perAccount,
            hasUnconvertible: hasUnconvertible
        )
    }

    /// Calcula patrimonio neto = assets - liabilities para todo el hogar.
    /// Segmenta el desglose para que la UI pueda mostrar 2 líneas + total.
    ///
    /// Variante client-side (deriva saldos de `transactions`). Se conserva para
    /// call sites que ya tienen las transacciones en memoria y para los tests;
    /// el Home y Cuentas usan la variante con `balances:` (RPC).
    static func netWorth(
        accounts: [Account],
        transactions: [Transaction],
        debts: [Debt],
        baseCurrency: String,
        fxRates: FXRateMap
    ) -> NetWorthBreakdown {
        // Delega en la variante con `balances:` en vez de duplicar la lógica. Antes eran dos
        // implementaciones paralelas y las DOS tenían el mismo bug de sumar monedas distintas —
        // que es lo que pasa cuando la misma regla vive en dos lugares.
        var balances: [UUID: Decimal] = [:]
        for account in accounts where account.isActive {
            balances[account.id] = currentBalance(
                account: account,
                transactions: transactions,
                baseCurrency: baseCurrency,
                fxRates: fxRates
            )
        }
        return netWorth(
            accounts: accounts,
            balances: balances,
            debts: debts,
            baseCurrency: baseCurrency,
            fxRates: fxRates
        )
    }
}

// MARK: - Models

/// Desglose de patrimonio neto. `netWorth` es propiedad derivada.
/// `Codable` porque viaja dentro del `HomeSnapshot` que se persiste en disco.
struct NetWorthBreakdown: Sendable, Equatable, Codable {
    let assets: Decimal
    let liabilities: Decimal
    let perAccount: [AccountBalance]

    /// Alguna cuenta o deuda quedó FUERA del total por no tener tasa de cambio disponible.
    /// La UI tiene que avisarlo: un total incompleto sin aviso se lee como completo.
    ///
    /// Default `false` para no romper el decode de los `HomeSnapshot` ya persistidos en disco
    /// de versiones anteriores — la lección `leccion-swiftdata-migracion-default` del harness.
    var hasUnconvertible: Bool = false

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
struct AccountBalance: Sendable, Equatable, Codable {
    let account: Account
    let balance: Decimal
}
