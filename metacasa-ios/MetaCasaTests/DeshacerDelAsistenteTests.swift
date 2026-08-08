import XCTest
@testable import Home_Finance

/// Poder deshacer lo que el asistente escribió.
///
/// Es la contracara honesta de dejar que la IA toque la base: la app no promete
/// que nunca se va a equivocar, promete que equivocarse no cuesta caro. Sin
/// esto, una interpretación errónea —el monto, la categoría, cuál de dos
/// movimientos parecidos— obligaba al usuario a ir a Movimientos, encontrar el
/// registro y arreglarlo a mano, sabiendo de antemano qué se había roto.
final class DeshacerDelAsistenteTests: XCTestCase {

    private let log = AssistantActionLog.shared

    private func movimiento(_ monto: Decimal, _ categoria: String) -> Transaction {
        Transaction(
            id: UUID(),
            householdId: UUID(),
            userId: UUID(),
            accountId: nil,
            type: .gasto,
            amount: monto,
            amountOriginal: nil,
            currencyOriginal: "ARS",
            fxRateToBase: nil,
            fxSource: nil,
            fxStatus: nil,
            category: categoria,
            subcategory: nil,
            account: nil,
            note: nil,
            date: Date(),
            periodYear: nil,
            periodMonth: nil,
            transferGroupId: nil,
            createdAt: nil
        )
    }

    override func setUp() async throws { await log.iniciarTurno() }

    func testUnTurnoNuevoArrancaSinNadaQueDeshacer() async {
        await log.registrar(AccionRevertible(clase: .alta, descripcion: "x", objetivo: movimiento(1, "A")))
        await log.iniciarTurno()
        let acciones = await log.delTurno()
        XCTAssertTrue(acciones.isEmpty, "lo del turno anterior no puede colgar del nuevo")
    }

    func testSeRegistranEnOrden() async {
        await log.registrar(AccionRevertible(clase: .alta, descripcion: "primero", objetivo: movimiento(1, "A")))
        await log.registrar(AccionRevertible(clase: .edicion, descripcion: "segundo", objetivo: movimiento(2, "B")))
        let acciones = await log.delTurno()
        XCTAssertEqual(acciones.map(\.descripcion), ["primero", "segundo"])
    }

    /// Trece altas de una tanda son trece cosas que deshacer, no una.
    func testUnaCargaMasivaDejaUnaAccionPorMovimiento() async {
        for i in 0..<13 {
            await log.registrar(AccionRevertible(
                clase: .alta, descripcion: "gasto \(i)", objetivo: movimiento(Decimal(i), "Varios")))
        }
        let acciones = await log.delTurno()
        XCTAssertEqual(acciones.count, 13)
    }

    /// En una edición se guarda el estado ANTERIOR: revertir es volver a
    /// escribirlo. Si se guardara el nuevo, "deshacer" reescribiría el error.
    func testLaEdicionGuardaElEstadoAnterior() async {
        let previo = movimiento(98800, "Herramientas")
        await log.registrar(AccionRevertible(
            clase: .edicion, descripcion: "Edición de ARS 98.800", objetivo: previo))
        let accion = await log.delTurno().first
        XCTAssertEqual(accion?.objetivo.amount, 98800)
        XCTAssertEqual(accion?.clase, .edicion)
    }

    func testLaAltaGuardaElMovimientoCreadoParaPoderBorrarlo() async {
        let creado = movimiento(45320, "Alimentos")
        await log.registrar(AccionRevertible(clase: .alta, descripcion: "Gasto", objetivo: creado))
        let accion = await log.delTurno().first
        XCTAssertEqual(accion?.objetivo.id, creado.id)
        XCTAssertEqual(accion?.clase, .alta)
    }

    /// Dos acciones distintas nunca comparten id, aunque describan lo mismo:
    /// deshacer una no puede sacar de la pantalla a la otra.
    func testDosAccionesIgualesSonDistintas() async {
        let a = AccionRevertible(clase: .alta, descripcion: "Gasto", objetivo: movimiento(1, "A"))
        let b = AccionRevertible(clase: .alta, descripcion: "Gasto", objetivo: movimiento(1, "A"))
        XCTAssertNotEqual(a, b)
    }
}
