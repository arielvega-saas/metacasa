import XCTest
@testable import Home_Finance

/// Tests de la moneda en el import de CSV.
///
/// El bug que motiva estos tests: `buildInputs` metía el monto crudo del archivo en `amount` y lo
/// etiquetaba con la moneda del archivo. Pero `amount` es, por contrato
/// (`metacasa-web/AGENTS_CONTRACT.md`), **siempre** la moneda base del hogar: es lo que suman los
/// totales del Home, `envelope_balance` y el matview mensual.
///
/// Importar un resumen en dólares a un hogar en pesos metía "100" donde iban 150.000 — no en una
/// fila, en el archivo entero. Es la misma forma del bug de 25× del patrimonio neto, multiplicada
/// por cada línea del CSV, y silenciosa: el número que queda es plausible.
final class ImportCurrencyTests: XCTestCase {

    private let hogar = UUID()
    private let usuario = UUID()

    private func tasas(_ pares: [String: Decimal]) -> FXRateMap {
        pares.reduce(into: FXRateMap()) { mapa, par in
            mapa[par.key] = FXRate(rate: par.value, updatedAt: "2026-08-03T00:00:00Z", source: "test")
        }
    }

    /// CSV mínimo sin columna de moneda: la moneda la define el usuario en el preview.
    private func csvSinMoneda() -> ParsedImport {
        TransactionCSVImporter.parse(text: """
        fecha,monto,tipo,categoria
        2026-05-10,100,gasto,Alimentación
        2026-05-11,250,gasto,Transporte
        """)
    }

    // MARK: - La conversión

    func testUnArchivoEnLaMonedaBaseNoSeConvierte() {
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: [:], fallbackCurrency: "ARS")
        XCTAssertEqual(r.rows[0].amountInBase, 100)
        XCTAssertEqual(r.rows[0].fxRateToBase, 1)
        XCTAssertTrue(r.rows.allSatisfy(\.isValid))
    }

    func testUnArchivoEnOtraMonedaSeLlevaABase() {
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: tasas(["USD": 1500]), fallbackCurrency: "USD")
        XCTAssertEqual(r.rows[0].amountInBase, 150_000, "USD 100 a 1500 son ARS 150.000")
        XCTAssertEqual(r.rows[1].amountInBase, 375_000)
        XCTAssertEqual(r.rows[0].fxRateToBase, 1500)
    }

    /// El corazón del fix: `amount` en base, el original preservado, y la invariante que los une.
    func testElInputGuardaBaseYOriginalYSeCumpleLaInvariante() {
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: tasas(["USD": 1500]), fallbackCurrency: "USD")
        let inputs = TransactionCSVImporter.buildInputs(
            from: r, householdId: hogar, userId: usuario, accountId: nil, defaultCurrency: "USD")

        XCTAssertEqual(inputs.count, 2)
        let primero = inputs[0]
        XCTAssertEqual(primero.amount, 150_000, "amount va SIEMPRE en base")
        XCTAssertEqual(primero.amountOriginal, 100, "el monto del archivo no se pierde")
        XCTAssertEqual(primero.currencyOriginal, "USD")
        XCTAssertEqual(primero.fxRateToBase, 1500)
        XCTAssertEqual(primero.amount, (primero.amountOriginal ?? 0) * (primero.fxRateToBase ?? 0),
                       "invariante: amount == amountOriginal * fxRateToBase")
    }

    /// La contra-invariante: sin el fix, esto pasaba y nadie se enteraba.
    func testSinConvertirElTotalSaldriaDivididoPorLaCotizacion() {
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: tasas(["USD": 1500]), fallbackCurrency: "USD")
        let inputs = TransactionCSVImporter.buildInputs(
            from: r, householdId: hogar, userId: usuario, accountId: nil, defaultCurrency: "USD")

        let totalGuardado = inputs.reduce(Decimal(0)) { $0 + $1.amount }
        let totalCrudo = inputs.reduce(Decimal(0)) { $0 + ($1.amountOriginal ?? 0) }
        XCTAssertEqual(totalGuardado, 525_000)
        XCTAssertEqual(totalCrudo, 350, "lo que se guardaba antes")
        XCTAssertEqual(totalGuardado / totalCrudo, 1500, "el error era exactamente la cotización")
    }

    // MARK: - Sin cotización: no se importa, no se inventa

    func testSinCotizacionLaFilaNoEsValida() {
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: [:], fallbackCurrency: "USD")
        XCTAssertNil(r.rows[0].amountInBase)
        XCTAssertFalse(r.rows[0].isValid, "sin tasa no hay forma honesta de guardar el monto")
        XCTAssertFalse(r.rows[0].issues.isEmpty, "y el usuario tiene que ver por qué")
    }

    /// Lo importante no es sólo que no se importe: es que **no se importe mal**.
    func testSinCotizacionNoSeImportaConElMontoCrudo() {
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: [:], fallbackCurrency: "USD")
        let inputs = TransactionCSVImporter.buildInputs(
            from: r, householdId: hogar, userId: usuario, accountId: nil, defaultCurrency: "USD")
        XCTAssertTrue(inputs.isEmpty, "antes entraban con el monto crudo, tratado como si fuera ARS")
    }

    func testElContadorDelPreviewCoincideConLoQueSeImporta() {
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: [:], fallbackCurrency: "USD")
        let inputs = TransactionCSVImporter.buildInputs(
            from: r, householdId: hogar, userId: usuario, accountId: nil, defaultCurrency: "USD")
        XCTAssertEqual(r.validCount, inputs.count,
                       "si el preview promete N y entran menos, el usuario aprueba algo que no pasó")
    }

    func testMonedasSinCotizacionSeListanUnaVez() {
        let faltan = TransactionCSVImporter.monedasSinCotizacion(
            csvSinMoneda(), base: "ARS", rates: [:], fallbackCurrency: "USD")
        XCTAssertEqual(faltan, ["USD"], "dos filas en USD son UN aviso, no dos")
    }

    // MARK: - La columna de moneda del archivo gana

    func testLaMonedaDeLaFilaGanaSobreLaDelArchivo() {
        let parsed = TransactionCSVImporter.parse(text: """
        fecha,monto,tipo,categoria,moneda
        2026-05-10,100,gasto,Alimentación,USD
        2026-05-11,5000,gasto,Transporte,ARS
        """)
        let r = TransactionCSVImporter.resolvingCurrency(
            parsed, base: "ARS", rates: tasas(["USD": 1500]), fallbackCurrency: "USD")
        XCTAssertEqual(r.rows[0].amountInBase, 150_000, "esta fila sí es USD")
        XCTAssertEqual(r.rows[1].amountInBase, 5_000, "esta ya venía en ARS: no se toca")
        XCTAssertEqual(r.rows[1].fxRateToBase, 1)
    }

    // MARK: - Cuenta

    func testLaCuentaElegidaLlegaATodasLasFilas() {
        let cuenta = UUID()
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: [:], fallbackCurrency: "ARS")
        let inputs = TransactionCSVImporter.buildInputs(
            from: r, householdId: hogar, userId: usuario, accountId: cuenta, defaultCurrency: "ARS")
        XCTAssertEqual(inputs.count, 2)
        XCTAssertTrue(inputs.allSatisfy { $0.accountId == cuenta })
    }

    func testSeSigueAceptandoImportarSinCuenta() {
        let r = TransactionCSVImporter.resolvingCurrency(
            csvSinMoneda(), base: "ARS", rates: [:], fallbackCurrency: "ARS")
        let inputs = TransactionCSVImporter.buildInputs(
            from: r, householdId: hogar, userId: usuario, accountId: nil, defaultCurrency: "ARS")
        XCTAssertTrue(inputs.allSatisfy { $0.accountId == nil })
    }
}
