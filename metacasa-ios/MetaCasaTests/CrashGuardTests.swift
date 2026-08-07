import XCTest
@testable import Home_Finance

/// Entradas que mataban la app.
///
/// Las tres vienen del mismo lugar: **un valor que no lo elige nuestro código**.
/// Dos los escribe el modelo de IA en el JSON de una tool y uno lo tipea el
/// usuario en un `TextField`. En Swift, convertir o indexar con un número fuera
/// de rango no devuelve `nil` ni lanza: hace trap, y un trap en Release es la
/// app cerrándose sin aviso — lo que el usuario ve como "Home Finance falló".
///
/// Un `do/catch` no protege de esto. La única defensa es acotar en el borde.
final class CrashGuardTests: XCTestCase {

    // MARK: - `limit` negativo desde el modelo

    /// Reproduce el clamp de `AIToolHandler.queryTransactions`.
    private func clampLimit(_ raw: Int?) -> Int {
        max(1, min(raw ?? 20, 50))
    }

    /// El caso real: el usuario pide "mostrame TODAS mis transacciones" y Claude
    /// emite `limit: -1`, que es la convención habitual de "sin límite". El
    /// `min(-1, 50)` lo dejaba pasar y `Array.prefix(-1)` mata la app.
    func testLimitNegativoNoLlegaAPrefix() {
        let limit = clampLimit(-1)
        XCTAssertGreaterThanOrEqual(limit, 1, "prefix() con largo negativo es un crash")
        // Y que efectivamente se pueda usar sin trap.
        XCTAssertEqual(Array([1, 2, 3].prefix(limit)).count, 1)
    }

    func testLimitCeroTampocoRompe() {
        XCTAssertGreaterThanOrEqual(clampLimit(0), 1)
    }

    func testLimitSigueAcotadoPorArriba() {
        XCTAssertEqual(clampLimit(9_999), 50)
    }

    func testLimitNormalNoSeToca() {
        XCTAssertEqual(clampLimit(20), 20)
        XCTAssertEqual(clampLimit(nil), 20)
    }

    // MARK: - `Double` fuera de rango desde el modelo

    /// Reproduce `JSONValue.intValue`. Trapeaba *antes* de llegar al handler,
    /// así que acotar en el handler no alcanzaba.
    private func intDesdeDouble(_ v: Double) -> Int? {
        Int(exactly: v.rounded())
    }

    func testDoubleGiganteDevuelveNilEnVezDeTrapear() {
        XCTAssertNil(intDesdeDouble(1e30))
        XCTAssertNil(intDesdeDouble(.infinity))
        XCTAssertNil(intDesdeDouble(.nan))
        XCTAssertNil(intDesdeDouble(-1e30))
    }

    /// Que la tolerancia no rompa el caso normal: el modelo suele mandar `20.0`
    /// donde el schema pide un entero.
    func testUnEnteroEscritoComoDecimalSigueSiendoEseEntero() {
        XCTAssertEqual(intDesdeDouble(20.0), 20)
        XCTAssertEqual(intDesdeDouble(19.6), 20)
        XCTAssertEqual(intDesdeDouble(-1.0), -1)
    }

    // MARK: - Años de la calculadora de interés compuesto

    /// Reproduce el clamp de `CompoundInterestCalculatorView.years`.
    private func clampYears(_ texto: String) -> Int {
        min(max(Int(texto) ?? 0, 0), 100)
    }

    /// 18 nueves entran en un `Int`, pero `years * 12` desborda y trapea. El
    /// campo es un `.numberPad` sin `maxLength`, así que se tipea de una.
    func testAniosEnormesNoDesbordanAlPasarAMeses() {
        let años = clampYears("999999999999999999")
        let meses = años * 12  // esto trapeaba
        XCTAssertLessThanOrEqual(meses, 1_200)
    }

    /// Antes del overflow ya había OOM: la proyección arma un punto por mes, en
    /// cada render y para cinco lectores distintos.
    func testElHorizonteMaximoSigueSiendoUnaSerieChica() {
        XCTAssertLessThanOrEqual(clampYears("100000") * 12, 1_200)
    }

    func testUnPlazoRealNoSeToca() {
        XCTAssertEqual(clampYears("30"), 30)
        XCTAssertEqual(clampYears(""), 0)
        XCTAssertEqual(clampYears("-5"), 0)
    }

    // MARK: - ETA de una meta inalcanzable

    /// Reproduce el clamp de `GoalDetailView`. Con una meta de mil millones y un
    /// aporte de cien por mes, el cociente supera `Int64.max` y `Int(ceil(...))`
    /// trapea **al abrir la pantalla**, sin que el usuario toque nada.
    func testMetaInalcanzableNoTrapeaAlConvertirAEntero() {
        let restante = 1_000_000_000_000_000_000_000.0
        let promedioMensual = 0.000_001
        let meses = min(restante / promedioMensual, 1200)
        XCTAssertEqual(Int(ceil(meses)), 1200, "tiene que quedar acotado, no trapear")
    }

    func testUnaMetaRealConservaSuEstimacion() {
        let meses = min(45_000.0 / 5_000.0, 1200)
        XCTAssertEqual(Int(ceil(meses)), 9)
    }
}
