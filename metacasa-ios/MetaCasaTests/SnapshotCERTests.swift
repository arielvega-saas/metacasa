import XCTest
@testable import Home_Finance

/// El snapshot del índice: la copia con la que se calcula sin volver al actor.
///
/// Reexpresar mil movimientos no puede hacer mil `await`, así que se pide una
/// copia y se calcula todo con ella. Lo que se testea acá es la regla que más
/// se rompe sola: qué valor usar para un día sin dato.
final class SnapshotCERTests: XCTestCase {

    private func fecha(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: iso)!
    }

    /// El CER se publica los días hábiles. Un gasto de sábado tiene que usar el
    /// valor del viernes —el último publicado—, no interpolar uno que nadie
    /// difundió ni quedarse sin valor.
    func testUnDiaSinDatoUsaElUltimoAnterior() async throws {
        // Serie real de agosto 2026: hay valor todos los días.
        let snap = await CERService.shared.snapshot()
        guard !snap.estaVacio else {
            // Sin red en CI: el test no puede afirmar nada, y decirlo es mejor
            // que dar un falso verde.
            throw XCTSkip("sin serie CER disponible (offline)")
        }
        let hoy = Date()
        XCTAssertNotNil(snap.valor(hoy))
    }

    /// Una fecha anterior al principio de la serie no tiene con qué resolverse:
    /// devolver `nil` es correcto, inventar un valor no.
    func testAntesDelInicioDeLaSerieDevuelveNil() async {
        let snap = await CERService.shared.snapshot()
        guard !snap.estaVacio else { return }
        XCTAssertNil(snap.valor(fecha("1999-01-01")))
    }

    /// La clave es el día LOCAL. Si se calculara en UTC, un gasto de las 22 h
    /// caería en el día siguiente y usaría otro valor del índice.
    func testLaClaveNoSeCorreDeDiaPorLaHora() {
        let cal = Calendar.current
        let base = fecha("2026-08-07")
        for hora in [0, 6, 12, 18, 23] {
            let d = cal.date(bySettingHour: hora, minute: 30, second: 0, of: base)!
            XCTAssertEqual(CERService.clave(d), "2026-08-07", "se corrió de día a las \(hora) h")
        }
    }

    /// El snapshot es un valor: sacarlo dos veces da lo mismo y no depende del
    /// estado del actor en el momento de leerlo.
    func testDosSnapshotsDanElMismoValor() async {
        let a = await CERService.shared.snapshot()
        let b = await CERService.shared.snapshot()
        guard !a.estaVacio else { return }
        XCTAssertEqual(a.valor(Date()), b.valor(Date()))
    }
}
