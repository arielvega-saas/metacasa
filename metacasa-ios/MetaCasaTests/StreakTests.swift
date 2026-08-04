import XCTest
@testable import Home_Finance

/// Tests de la racha de días consecutivos.
///
/// Existen porque el cálculo vivía embebido en `HomeViewModel`, sin un solo test, y **siempre
/// devolvía 1**: un `days.remove(prev)` borraba del set el día que la vuelta siguiente iba a
/// consultar. Se descubrió mirando la pantalla —el Home decía "1 día seguido" con movimientos en
/// cuatro días consecutivos—, no leyendo el código.
final class StreakTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func hoy() -> Date { calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 12))! }

    private func tx(diasAtras: Int) -> Transaction {
        let fecha = calendar.date(byAdding: .day, value: -diasAtras, to: hoy())!
        return Transaction(
            id: UUID(), householdId: UUID(), userId: UUID(), accountId: nil,
            type: .gasto, amount: 1000, amountOriginal: 1000, currencyOriginal: "ARS",
            fxRateToBase: 1, fxSource: nil, fxStatus: nil,
            category: "Alimentación", subcategory: nil, account: nil, note: nil,
            date: fecha, periodYear: nil, periodMonth: nil,
            transferGroupId: nil, createdAt: nil
        )
    }

    private func racha(_ diasAtras: [Int]) -> Int {
        Streak.consecutiveDays(
            transactions: diasAtras.map { tx(diasAtras: $0) },
            now: hoy(), calendar: calendar
        )
    }

    /// El caso que destapó el bug: cuatro días seguidos daban 1.
    func testCuatroDiasSeguidosDanCuatro() {
        XCTAssertEqual(racha([0, 1, 2, 3]), 4)
    }

    func testSoloHoyDaUno() {
        XCTAssertEqual(racha([0]), 1)
    }

    func testSinMovimientosHoyDaCero() {
        // La racha cuenta hacia atrás DESDE hoy: si hoy no cargaste, se cortó.
        XCTAssertEqual(racha([1, 2, 3]), 0)
    }

    func testUnHuecoCortaLaRacha() {
        // Hoy y ayer sí, anteayer no, y antes sí: la racha es 2, no 4.
        XCTAssertEqual(racha([0, 1, 3, 4]), 2)
    }

    func testVariosMovimientosElMismoDiaCuentanUnaVez() {
        XCTAssertEqual(racha([0, 0, 0, 1]), 2)
    }

    func testListaVacia() {
        XCTAssertEqual(racha([]), 0)
    }

    /// Una racha larga tiene que contarse entera, no toparse en un valor chico.
    func testRachaLarga() {
        XCTAssertEqual(racha(Array(0...45)), 46)
    }
}
