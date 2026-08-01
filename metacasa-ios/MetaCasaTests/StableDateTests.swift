import XCTest
@testable import Home_Finance

/// Tests de la normalización de fecha para guardar.
///
/// Es el bug más silencioso que tenía la app: no muestra un número raro, simplemente pone el gasto
/// en el mes que no es. El usuario no tiene forma de darse cuenta salvo que audite el sobre.
final class StableDateTests: XCTestCase {

    private func utcCalendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Construye una fecha en un huso dado (el "momento" en que el usuario tocó Guardar).
    private func moment(_ y: Int, _ m: Int, _ d: Int, _ h: Int, tz: String) -> (date: Date, calendar: Calendar) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        let date = cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: 0))!
        return (date, cal)
    }

    private func utcParts(_ date: Date) -> DateComponents {
        utcCalendar().dateComponents([.year, .month, .day, .hour], from: date)
    }

    // MARK: - El caso que motivó el fix

    func testArgentina31DeEneroALas22NoSeVaAFebrero() {
        // UTC−3: las 22:00 del 31-ene son las 01:00 UTC del 1-feb. Sin normalizar, el gasto
        // contaba en el presupuesto de FEBRERO.
        let (date, cal) = moment(2026, 1, 31, 22, tz: "America/Argentina/Buenos_Aires")
        let parts = utcParts(date.stableForStorage(calendar: cal))
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 1, "debe seguir siendo ENERO")
        XCTAssertEqual(parts.day, 31)
        XCTAssertEqual(parts.hour, 12, "mediodía UTC")
    }

    func testMexicoAUltimaHoraDelMesTampocoSeCorre() {
        // UTC−6: la franja rota iba de 18:00 a medianoche.
        let (date, cal) = moment(2026, 3, 31, 23, tz: "America/Mexico_City")
        let parts = utcParts(date.stableForStorage(calendar: cal))
        XCTAssertEqual(parts.month, 3)
        XCTAssertEqual(parts.day, 31)
    }

    /// El otro lado del mundo: un huso POSITIVO puede correr la fecha hacia atrás.
    func testHusoPositivoAPrimeraHoraNoRetrocedeDeMes() {
        // UTC+13: las 01:00 del 1-feb en Auckland son las 12:00 UTC del 31-ene.
        let (date, cal) = moment(2026, 2, 1, 1, tz: "Pacific/Auckland")
        let parts = utcParts(date.stableForStorage(calendar: cal))
        XCTAssertEqual(parts.month, 2, "debe seguir siendo FEBRERO")
        XCTAssertEqual(parts.day, 1)
    }

    // MARK: - Invariantes

    /// Mediodía da 12 h de margen a cada lado: ningún huso real puede correr el día.
    func testNingunHusoNiHoraCorreLaFecha() {
        let zonas = ["Pacific/Kiritimati",              // UTC+14, el extremo
                     "Pacific/Auckland",                // UTC+13
                     "Europe/Madrid",
                     "UTC",
                     "America/Argentina/Buenos_Aires",  // UTC−3
                     "America/Mexico_City",             // UTC−6
                     "Pacific/Honolulu",                // UTC−10
                     "Etc/GMT+12"]                      // UTC−12, el otro extremo
        for tz in zonas {
            for hora in [0, 6, 12, 18, 23] {
                let (date, cal) = moment(2026, 6, 15, hora, tz: tz)
                let parts = utcParts(date.stableForStorage(calendar: cal))
                XCTAssertEqual(parts.day, 15, "\(tz) a las \(hora)h corrió el día a \(parts.day ?? -1)")
                XCTAssertEqual(parts.month, 6, "\(tz) a las \(hora)h corrió el mes")
            }
        }
    }

    func testEsIdempotente() {
        // Normalizar algo ya normalizado no debe moverlo (los datos se releen y reguardan al editar).
        let (date, cal) = moment(2026, 1, 31, 22, tz: "America/Argentina/Buenos_Aires")
        let once = date.stableForStorage(calendar: cal)
        let twice = once.stableForStorage(calendar: cal)
        XCTAssertEqual(once, twice)
    }

    func testAnioBisiestoSeConserva() {
        let (date, cal) = moment(2028, 2, 29, 21, tz: "America/Argentina/Buenos_Aires")
        let parts = utcParts(date.stableForStorage(calendar: cal))
        XCTAssertEqual(parts.month, 2)
        XCTAssertEqual(parts.day, 29)
    }
}
