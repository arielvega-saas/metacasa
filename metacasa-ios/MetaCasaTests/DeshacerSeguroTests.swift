import XCTest
@testable import Home_Finance

/// Deshacer no puede pisar un cambio posterior.
///
/// La tarjeta de "Deshacer" queda en el chat. Si el usuario edita ese mismo
/// movimiento a mano media hora después —o lo edita otra persona del hogar— y
/// recién ahí toca Deshacer, revertir al estado anterior se llevaría puesto ese
/// cambio sin decir nada. Por eso cada acción guarda un testigo de cómo quedó.
final class DeshacerSeguroTests: XCTestCase {

    private func mov(_ monto: Decimal, _ categoria: String, nota: String? = nil,
                     fecha: Date = Date(), tipo: TxType = .gasto) -> Transaction {
        Transaction(
            id: UUID(), householdId: UUID(), userId: UUID(), accountId: nil,
            type: tipo, amount: monto, amountOriginal: nil, currencyOriginal: "ARS",
            fxRateToBase: nil, fxSource: nil, fxStatus: nil,
            category: categoria, subcategory: nil, account: nil, note: nota,
            date: fecha, periodYear: nil, periodMonth: nil,
            transferGroupId: nil, createdAt: nil
        )
    }

    // MARK: - Qué cuenta como "cambió"

    func testUnMovimientoIgualEsEquivalente() {
        let a = mov(1000, "Alimentación", nota: "super")
        var b = a
        b.householdId = UUID()   // campo de servicio: no cuenta
        XCTAssertTrue(AssistantActionLog.equivalentes(a, b))
    }

    func testCambiarElMontoLoHaceDistinto() {
        let a = mov(1000, "Alimentación")
        var b = a; b.amount = 1001
        XCTAssertFalse(AssistantActionLog.equivalentes(a, b))
    }

    func testCambiarLaCategoriaLoHaceDistinto() {
        let a = mov(1000, "Alimentación")
        var b = a; b.category = "Ocio"
        XCTAssertFalse(AssistantActionLog.equivalentes(a, b))
    }

    func testCambiarLaNotaLoHaceDistinto() {
        let a = mov(1000, "Alimentación", nota: "super")
        var b = a; b.note = "kiosco"
        XCTAssertFalse(AssistantActionLog.equivalentes(a, b))
    }

    /// Nota vacía y nota nula son lo mismo para el usuario.
    func testNotaVaciaYNulaSonLoMismo() {
        let a = mov(1000, "Alimentación", nota: nil)
        var b = a; b.note = ""
        XCTAssertTrue(AssistantActionLog.equivalentes(a, b))
    }

    func testCambiarElTipoLoHaceDistinto() {
        let a = mov(1000, "Sueldo", tipo: .gasto)
        var b = a; b.type = .ingreso
        XCTAssertFalse(AssistantActionLog.equivalentes(a, b))
    }

    /// La fecha se compara por DÍA: la hora exacta la fija el servidor y no es
    /// algo que el usuario haya cambiado.
    func testLaFechaSeComparaPorDiaYNoPorHora() {
        let cal = Calendar.current
        let base = mov(1000, "Alimentación")
        var otraHora = base
        otraHora.date = cal.date(byAdding: .hour, value: 9, to: base.date)!
        XCTAssertTrue(AssistantActionLog.equivalentes(base, otraHora))

        var otroDia = base
        otroDia.date = cal.date(byAdding: .day, value: 1, to: base.date)!
        XCTAssertFalse(AssistantActionLog.equivalentes(base, otroDia))
    }

    // MARK: - Los mensajes de error explican qué hacer

    func testLosErroresDicenQuePasoYQueNoSeToco() {
        let cambio = ErrorAlDeshacer.cambioDespues.errorDescription ?? ""
        XCTAssertTrue(cambio.contains("cambió"))
        XCTAssertTrue(cambio.lowercased().contains("movimientos"), "hay que decirle dónde mirar")

        let borrado = ErrorAlDeshacer.yaNoExiste.errorDescription ?? ""
        XCTAssertTrue(borrado.contains("ya no existe"))
    }

    // MARK: - La acción sobrevive al disco

    /// La tarjeta se pierde al cerrar el chat si la acción no se puede guardar.
    func testUnaAccionSeCodificaYVuelve() throws {
        // `Decimal(string:)` y no el literal: un literal con decimales pasa
        // por `Double` y arrastra el error binario — es el mismo bug que
        // guardaba 78972.57000000001024 en la base.
        let creado = mov(Decimal(string: "78972.57")!, "Herramientas", nota: "HIGGSFIELD")
        let accion = AccionRevertible(clase: .alta, descripcion: "Gasto de ARS 78.972,57",
                                      objetivo: creado, resultado: creado)
        let data = try JSONEncoder().encode(accion)
        let vuelta = try JSONDecoder().decode(AccionRevertible.self, from: data)

        XCTAssertEqual(vuelta.id, accion.id)
        XCTAssertEqual(vuelta.clase, .alta)
        XCTAssertEqual(vuelta.objetivo.amount, Decimal(string: "78972.57"))
        XCTAssertEqual(vuelta.resultado?.id, creado.id)
    }

    /// Una acción vieja, guardada antes de que existiera el testigo, tiene que
    /// seguir decodificando: si no, el chat entero deja de cargar.
    func testUnaAccionSinTestigoSigueDecodificando() throws {
        let creado = mov(1000, "Ocio")
        let sinTestigo = AccionRevertible(clase: .alta, descripcion: "x", objetivo: creado)
        let data = try JSONEncoder().encode(sinTestigo)
        let vuelta = try JSONDecoder().decode(AccionRevertible.self, from: data)
        XCTAssertNil(vuelta.resultado)
    }
}
