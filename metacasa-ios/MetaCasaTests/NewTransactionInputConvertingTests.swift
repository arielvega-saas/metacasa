import XCTest
@testable import Home_Finance

/// Tests del constructor que lleva un monto a la moneda base del hogar.
///
/// Existe porque la misma regla estaba reimplementada —o ausente— en los 8 caminos que crean
/// transacciones. El caso más caro era el recibo por foto: escanear un ticket de USD 100 en un
/// hogar en pesos insertaba `amount = 100` etiquetado "USD". Los totales quedaban divididos por
/// la cotización y la lista mostraba "US$ 100" donde el usuario había gastado ARS 150.000.
///
/// No hay error, no hay crash: el número que queda es plausible. Por eso los tests van sobre la
/// **invariante** (`amount == amountOriginal * fxRateToBase`) y no sobre valores sueltos.
final class NewTransactionInputConvertingTests: XCTestCase {

    private let hogar = UUID()
    private let usuario = UUID()

    private func tasas(_ pares: [String: Decimal]) -> FXRateMap {
        pares.reduce(into: FXRateMap()) { mapa, par in
            mapa[par.key] = FXRate(rate: par.value, updatedAt: "2026-08-03T00:00:00Z", source: "test")
        }
    }

    private func construir(
        _ monto: Decimal, _ moneda: String?, base: String, rates: FXRateMap
    ) throws -> NewTransactionInput {
        try .converting(
            householdId: hogar, userId: usuario, accountId: nil, type: .gasto,
            amountOriginal: monto, currency: moneda, baseCurrency: base, rates: rates,
            category: "Alimentación", date: Date()
        )
    }

    // MARK: - Conversión

    func testEnLaMonedaBaseNoSeConvierte() throws {
        let i = try construir(1000, "ARS", base: "ARS", rates: [:])
        XCTAssertEqual(i.amount, 1000)
        XCTAssertEqual(i.amountOriginal, 1000)
        XCTAssertEqual(i.fxRateToBase, 1)
    }

    func testSinMonedaSeAsumeLaBase() throws {
        let i = try construir(1000, nil, base: "ARS", rates: [:])
        XCTAssertEqual(i.amount, 1000)
        XCTAssertEqual(i.currencyOriginal, "ARS")
        XCTAssertEqual(i.fxRateToBase, 1)
    }

    /// El caso del recibo escaneado: éste es el bug que se arregla.
    func testMonedaExtranjeraSeLlevaABaseYConservaElOriginal() throws {
        let i = try construir(100, "USD", base: "ARS", rates: tasas(["USD": 1500]))
        XCTAssertEqual(i.amount, 150_000, "lo que suman los totales")
        XCTAssertEqual(i.amountOriginal, 100, "lo que el usuario ve como 'US$ 100'")
        XCTAssertEqual(i.currencyOriginal, "USD")
        XCTAssertEqual(i.fxRateToBase, 1500)
    }

    func testSeCumpleLaInvariante() throws {
        for (monto, tasa) in [(Decimal(100), Decimal(1500)), (33.33, 1234.56), (1, 0.85)] {
            let i = try construir(monto, "USD", base: "ARS", rates: tasas(["USD": tasa]))
            XCTAssertEqual(i.amount, (i.amountOriginal ?? 0) * (i.fxRateToBase ?? 0),
                           "amount == amountOriginal * fxRateToBase con monto \(monto) y tasa \(tasa)")
        }
    }

    func testLaMonedaSeNormalizaAMayusculas() throws {
        let i = try construir(100, "usd", base: "ars", rates: tasas(["USD": 1500]))
        XCTAssertEqual(i.currencyOriginal, "USD")
        XCTAssertEqual(i.amount, 150_000, "'usd' y 'ARS' tienen que matchear igual")
    }

    // MARK: - Sin cotización: falla fuerte

    func testSinCotizacionTira() {
        XCTAssertThrowsError(try construir(100, "EUR", base: "ARS", rates: tasas(["USD": 1500]))) { error in
            guard case FXConversionError.sinCotizacion(let moneda, let base) = error else {
                return XCTFail("debería ser sinCotizacion, fue \(error)")
            }
            XCTAssertEqual(moneda, "EUR")
            XCTAssertEqual(base, "ARS")
        }
    }

    /// Lo que NO tiene que pasar: guardar el monto crudo como si ya estuviera en base.
    /// Antes ése era el comportamiento, y el error era exactamente el factor de la cotización.
    func testSinCotizacionNoCaeAlMontoCrudo() {
        let resultado = try? construir(100, "EUR", base: "ARS", rates: [:])
        XCTAssertNil(resultado, "fallar es correcto; guardar 100 como si fueran ARS 100 no lo es")
    }

    func testElErrorDiceQueHacer() {
        let error = FXConversionError.sinCotizacion(moneda: "EUR", base: "ARS")
        let texto = error.errorDescription ?? ""
        XCTAssertTrue(texto.contains("EUR") && texto.contains("ARS"),
                      "el mensaje tiene que nombrar las dos monedas, no decir 'error al guardar'")
        XCTAssertFalse(texto.isEmpty)
    }

    // MARK: - Fecha

    /// El init normaliza la fecha; `converting` no puede saltearse esa garantía.
    func testLaFechaSigueNormalizandose() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let medianoche = cal.date(from: DateComponents(year: 2026, month: 5, day: 31))!
        let i = try construir(100, "ARS", base: "ARS", rates: [:])
        _ = medianoche
        XCTAssertEqual(i.date, i.date.stableForStorage(), "la fecha tiene que quedar ya normalizada")
    }
}
