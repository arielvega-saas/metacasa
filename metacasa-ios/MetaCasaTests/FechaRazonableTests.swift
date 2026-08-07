import XCTest
@testable import Home_Finance

/// El año que el modelo inventa cuando el usuario no lo escribe.
///
/// Caso real: el usuario pegó su resumen del banco con "05/08" y "06/08" —día y
/// mes, sin año— y pidió cargarlos. El modelo completó con **2024**, el año de
/// sus datos de entrenamiento. Los trece gastos se guardaron perfectos… dos años
/// atrás: fuera del mes, fuera del presupuesto, fuera de los reportes. Y el
/// asistente contestó "cargué los 13 gastos" sin notar que acababa de llenar un
/// mes que estaba vacío desde hacía dos años.
///
/// Decirle la fecha de hoy en el prompt es necesario pero no suficiente: un
/// prompt es una sugerencia. Todo dato que viene del modelo se valida antes de
/// escribirlo, igual que el `limit` o el `householdId`.
final class FechaRazonableTests: XCTestCase {

    private let cal = Calendar.current

    private func fecha(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: iso)!
    }

    private func iso(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: d)
    }

    // MARK: - El caso que se rompió

    func testElAñoDeEntrenamientoSeCorrigeAlActual() async {
        let hoy = fecha("2026-08-07")
        let r = await AIToolHandler.fechaRazonable(fecha("2024-08-05"), hoy: hoy)
        XCTAssertEqual(iso(r.fecha), "2026-08-05", "conserva día y mes, corrige el año")
        XCTAssertTrue(r.ajustada, "y avisa que lo corrigió")
    }

    func testCorregirNoInventaOtroDia() async {
        let hoy = fecha("2026-08-07")
        let r = await AIToolHandler.fechaRazonable(fecha("2024-08-06"), hoy: hoy)
        XCTAssertEqual(cal.component(.day, from: r.fecha), 6)
        XCTAssertEqual(cal.component(.month, from: r.fecha), 8)
    }

    /// Si el día ya pasó este año, se queda en este año — no salta al anterior.
    func testUnaFechaDeEsteAñoNoSeToca() async {
        let hoy = fecha("2026-08-07")
        let r = await AIToolHandler.fechaRazonable(fecha("2026-08-05"), hoy: hoy)
        XCTAssertEqual(iso(r.fecha), "2026-08-05")
        XCTAssertFalse(r.ajustada)
    }

    /// Diciembre visto desde enero: "el 20/12" es del año pasado, no del que viene.
    func testUnDiaQueEsteAñoCaeriaEnElFuturoVaAlAñoAnterior() async {
        let hoy = fecha("2026-01-10")
        let r = await AIToolHandler.fechaRazonable(fecha("2019-12-20"), hoy: hoy)
        XCTAssertEqual(iso(r.fecha), "2025-12-20")
        XCTAssertTrue(r.ajustada)
    }

    // MARK: - Lo que NO hay que romper

    /// El usuario puede cargar algo de hace meses a propósito. Trece meses de
    /// ventana cubren "el año pasado por esta época" sin tocar nada.
    func testUnaFechaVieja_peroRazonable_seRespeta() async {
        let hoy = fecha("2026-08-07")
        let r = await AIToolHandler.fechaRazonable(fecha("2025-10-15"), hoy: hoy)
        XCTAssertEqual(iso(r.fecha), "2025-10-15")
        XCTAssertFalse(r.ajustada)
    }

    /// Un gasto programado o un vencimiento cercano es legítimo.
    func testUnaFechaFuturaCercanaSeRespeta() async {
        let hoy = fecha("2026-08-07")
        let r = await AIToolHandler.fechaRazonable(fecha("2026-08-25"), hoy: hoy)
        XCTAssertEqual(iso(r.fecha), "2026-08-25")
        XCTAssertFalse(r.ajustada)
    }

    func testUnaFechaLejanaEnElFuturoTambienSeCorrige() async {
        let hoy = fecha("2026-08-07")
        let r = await AIToolHandler.fechaRazonable(fecha("2031-08-05"), hoy: hoy)
        XCTAssertEqual(iso(r.fecha), "2026-08-05")
        XCTAssertTrue(r.ajustada)
    }

    func testSinFechaUsaHoyYNoSeConsideraAjuste() async {
        let hoy = fecha("2026-08-07")
        let r = await AIToolHandler.fechaRazonable(nil, hoy: hoy)
        XCTAssertEqual(iso(r.fecha), "2026-08-07")
        XCTAssertFalse(r.ajustada, "no hubo nada que corregir")
    }

    /// El 29 de febrero sólo existe en bisiesto: reubicarlo no puede reventar.
    func testUnBisiestoNoRompeAlReubicarse() async {
        let hoy = fecha("2026-08-07")   // 2026 no es bisiesto
        let r = await AIToolHandler.fechaRazonable(fecha("2020-02-29"), hoy: hoy)
        XCTAssertLessThanOrEqual(r.fecha, fecha("2026-09-07"), "no puede quedar en el futuro lejano")
        XCTAssertTrue(r.ajustada)
    }

    // MARK: - El prompt también tiene que decir la fecha

    func testElPromptIncluyeLaFechaDeHoy() {
        XCTAssertEqual(AISystemPromptV2.hoyISO(), iso(Date()))
    }
}
