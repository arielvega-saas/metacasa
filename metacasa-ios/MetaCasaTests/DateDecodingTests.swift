import XCTest
@testable import Home_Finance

/// Decodificación de fechas que vienen de Postgres.
///
/// Existen porque el decoder parseaba **todo** en UTC, incluidas las columnas `date`.
/// Una fecha-sola no es un instante: es un día del calendario del usuario. Parseada en
/// UTC y mostrada en local se corre un día para atrás en cualquier huso negativo —toda
/// LatAm—, así que un vencimiento de HOY aparecía como "1 día de atraso", y las fechas
/// de metas y deudas mostraban el día anterior. Se vio en el simulador cargando los
/// vencimientos de la cuenta de App Review.
final class DateDecodingTests: XCTestCase {

    private struct Fila: Decodable {
        let d: Date
    }

    private func decodeDate(_ raw: String) throws -> Date {
        let json = Data("{\"d\":\"\(raw)\"}".utf8)
        return try SupabaseRPC.decoder.decode(Fila.self, from: json).d
    }

    /// El caso que rompía: `date` de Postgres, sin hora.
    func testUnaFechaSolaEsElDiaLocalQueDice() throws {
        let d = try decodeDate("2026-08-05")
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.year, from: d), 2026)
        XCTAssertEqual(cal.component(.month, from: d), 8)
        XCTAssertEqual(cal.component(.day, from: d), 5, "No puede caer en el 4")
    }

    /// El síntoma exacto: `startOfDay` local, que es lo que usa `Bill.dueStatus`.
    func testStartOfDayNoRetrocedeUnDia() throws {
        let d = try decodeDate("2026-08-05")
        let inicio = Calendar.current.startOfDay(for: d)
        XCTAssertEqual(Calendar.current.component(.day, from: inicio), 5)
    }

    func testElPrimeroDeMesNoSeCaeAlMesAnterior() throws {
        let d = try decodeDate("2026-08-01")
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: d), 8, "No puede caer en julio")
        XCTAssertEqual(cal.component(.day, from: d), 1)
    }

    func testAnioBisiesto() throws {
        let d = try decodeDate("2028-02-29")
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: d), 2)
        XCTAssertEqual(cal.component(.day, from: d), 29)
    }

    /// Los timestamps SÍ son instantes y siguen interpretándose en UTC. El mediodía UTC
    /// que escribe `toStableDate` tiene que seguir cayendo en el mismo día en LatAm.
    func testUnTimestampSigueSiendoUTC() throws {
        let d = try decodeDate("2026-08-04T12:00:00.000Z")
        XCTAssertEqual(d.timeIntervalSince1970, 1_785_844_800, accuracy: 1)

        // Y sigue cayendo en el día 4 visto desde Argentina (UTC-3, o sea 09:00).
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        XCTAssertEqual(cal.component(.day, from: d), 4)
    }

    func testFormatoPostgresConMicrosegundos() throws {
        let d = try decodeDate("2026-04-20 00:50:41.767043+00")
        XCTAssertEqual(Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(secondsFromGMT: 0)!, from: d).day, 20)
    }

    func testUnFormatoDesconocidoSigueTirando() {
        XCTAssertThrowsError(try decodeDate("20 de agosto"))
    }
}
