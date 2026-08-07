import XCTest
@testable import Home_Finance

/// El saldo de una cuenta no puede mezclar monedas.
///
/// `Account.startingBalance` está en la moneda de la cuenta y `Transaction.amount`
/// en la moneda BASE del hogar. Sumarlos directo era sumar dólares con pesos: una
/// caja de ahorro en USD dentro de un hogar en ARS mostraba el saldo multiplicado
/// por la cotización, y el dashboard lo volvía a convertir *desde* USD, elevando
/// el error al cuadrado.
///
/// La misma regla vive en la web (`lib/db/account-balance.ts`) y en el RPC
/// `account_balances`. Los tres tienen que dar el mismo número: si este test
/// cambia, hay que cambiar los otros dos.
@MainActor
final class AccountBalanceCurrencyTests: XCTestCase {

    private func cuenta(_ moneda: String, inicial: Decimal, id: UUID) -> Account {
        Account(
            id: id, householdId: UUID(), name: "Caja \(moneda)", type: .savings,
            currency: moneda, startingBalance: inicial, institution: nil,
            accountNumberLast4: nil, icon: nil, color: nil, displayOrder: 0,
            isActive: true, notes: nil, ownership: .personal, ownerUserId: nil,
            createdBy: UUID(), createdAt: nil, updatedAt: nil
        )
    }

    private func mov(
        _ tipo: TxType, cuenta id: UUID,
        base: Decimal, original: Decimal?, moneda: String?
    ) -> Transaction {
        Transaction(
            id: UUID(), householdId: UUID(), userId: UUID(), accountId: id,
            type: tipo, amount: base, amountOriginal: original,
            currencyOriginal: moneda, fxRateToBase: nil, fxSource: nil, fxStatus: nil,
            category: "Test", subcategory: nil, account: nil, note: nil,
            date: Date(), periodYear: nil, periodMonth: nil, createdAt: nil
        )
    }

    /// El caso exacto que estaba roto: US$1.000 iniciales + un ingreso de US$500
    /// cargado a tasa 1000 (`amount` base = 500.000) daba **US$ 501.000**.
    func testCuentaEnOtraMonedaNoSumaElMontoEnMonedaBase() {
        let id = UUID()
        let saldo = AccountBalanceService.currentBalance(
            account: cuenta("USD", inicial: 1000, id: id),
            transactions: [mov(.ingreso, cuenta: id, base: 500_000, original: 500, moneda: "USD")],
            baseCurrency: "ARS",
            fxRates: ["USD": FXRate(rate: 1000, updatedAt: "2026-08-06T00:00:00Z", source: "manual")]
        )
        XCTAssertEqual(saldo, 1500)
        XCTAssertNotEqual(saldo, 501_000, "estaría sumando pesos a un saldo en dólares")
    }

    /// Cargar un gasto en pesos contra una cuenta en dólares: hay que traerlo a
    /// la moneda de la cuenta antes de restarlo.
    func testUnMovimientoEnOtraMonedaSeConvierteALaDeLaCuenta() {
        let id = UUID()
        let saldo = AccountBalanceService.currentBalance(
            account: cuenta("USD", inicial: 1000, id: id),
            transactions: [mov(.gasto, cuenta: id, base: 100_000, original: 100_000, moneda: "ARS")],
            baseCurrency: "ARS",
            fxRates: ["USD": FXRate(rate: 1000, updatedAt: "2026-08-06T00:00:00Z", source: "manual")]
        )
        XCTAssertEqual(saldo, 900) // 100.000 ARS / 1000 = US$100
    }

    /// Descartar el movimiento dejaría el saldo mal sin que nada lo indique.
    func testSinTasaElMovimientoSigueContando() {
        let id = UUID()
        let saldo = AccountBalanceService.currentBalance(
            account: cuenta("USD", inicial: 1000, id: id),
            transactions: [mov(.gasto, cuenta: id, base: 100_000, original: 100_000, moneda: "ARS")],
            baseCurrency: "ARS",
            fxRates: [:]
        )
        XCTAssertNotEqual(saldo, 1000, "no puede ignorar el movimiento en silencio")
    }

    /// El caso mayoritario no cambia: cuenta en la moneda del hogar.
    func testCuentaEnLaMonedaDelHogarSeComportaIgualQueAntes() {
        let id = UUID()
        let saldo = AccountBalanceService.currentBalance(
            account: cuenta("ARS", inicial: 100_000, id: id),
            transactions: [
                mov(.ingreso, cuenta: id, base: 50_000, original: 50_000, moneda: "ARS"),
                mov(.gasto, cuenta: id, base: 20_000, original: 20_000, moneda: "ARS"),
            ],
            baseCurrency: "ARS",
            fxRates: [:]
        )
        XCTAssertEqual(saldo, 130_000)
    }

    /// Datos viejos, anteriores al multi-moneda, no tienen `amountOriginal`.
    func testSinAmountOriginalCaeAlMontoEnBase() {
        let id = UUID()
        let saldo = AccountBalanceService.currentBalance(
            account: cuenta("ARS", inicial: 0, id: id),
            transactions: [mov(.ingreso, cuenta: id, base: 7_650_000, original: nil, moneda: nil)],
            baseCurrency: "ARS",
            fxRates: [:]
        )
        XCTAssertEqual(saldo, 7_650_000)
    }

    func testLasTxDeOtrasCuentasNoAfectan() {
        let id = UUID()
        let saldo = AccountBalanceService.currentBalance(
            account: cuenta("ARS", inicial: 5_000, id: id),
            transactions: [mov(.gasto, cuenta: UUID(), base: 1_000, original: 1_000, moneda: "ARS")],
            baseCurrency: "ARS",
            fxRates: [:]
        )
        XCTAssertEqual(saldo, 5_000)
    }
}
