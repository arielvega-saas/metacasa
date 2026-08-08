import XCTest
@testable import Home_Finance

/// El botón "Deshacer" tiene que sobrevivir a cerrar el chat.
///
/// Vivía sólo en memoria: al reabrir el asistente la conversación se rehidrata
/// desde el disco y la tarjeta desaparecía, aunque el movimiento siguiera
/// cargado. El usuario lo reportó como una pérdida, y tenía razón: el momento
/// en que uno se da cuenta de que un gasto quedó mal suele ser más tarde, no en
/// el mismo minuto.
final class RevertiblesPersistidosTests: XCTestCase {

    private let hogar = UUID()
    private let usuario = UUID()
    private let svc = ChatPersistenceService.shared

    override func setUp() async throws { await svc.clearAll(householdId: hogar) }
    override func tearDown() async throws { await svc.clearAll(householdId: hogar) }

    private func mov(_ monto: Decimal) -> Transaction {
        Transaction(
            id: UUID(), householdId: hogar, userId: usuario, accountId: nil,
            type: .gasto, amount: monto, amountOriginal: nil, currencyOriginal: "ARS",
            fxRateToBase: nil, fxSource: nil, fxStatus: nil,
            category: "Alimentación", subcategory: nil, account: nil, note: nil,
            date: Date(), periodYear: nil, periodMonth: nil,
            transferGroupId: nil, createdAt: nil
        )
    }

    func testUnaAccionSobreviveElViajeAlDiscoYVuelta() async throws {
        let creado = mov(Decimal(string: "45320.50")!)
        let accion = AccionRevertible(clase: .alta, descripcion: "Gasto de ARS 45.320,50",
                                      objetivo: creado, resultado: creado)
        await svc.appendMessage(
            ChatMessageRecord(role: .assistant, content: "✅ Cargué el gasto.",
                              revertibles: [accion]),
            householdId: hogar, userId: usuario
        )

        let leida = await svc.loadCurrent(householdId: hogar, userId: usuario)
        let guardadas = try XCTUnwrap(leida.messages.first?.revertibles)
        XCTAssertEqual(guardadas.count, 1)
        XCTAssertEqual(guardadas.first?.id, accion.id)
        XCTAssertEqual(guardadas.first?.objetivo.amount, Decimal(string: "45320.50"))
        XCTAssertEqual(guardadas.first?.resultado?.id, creado.id)
    }

    /// Una carga de trece movimientos deja trece cosas que deshacer, y las trece
    /// tienen que sobrevivir.
    func testUnaTandaCompletaSobrevive() async throws {
        let acciones = (0..<13).map { i in
            AccionRevertible(clase: .alta, descripcion: "Gasto \(i)",
                             objetivo: mov(Decimal(i * 1000)), resultado: mov(Decimal(i * 1000)))
        }
        await svc.appendMessage(
            ChatMessageRecord(role: .assistant, content: "✅ Cargué 13 movimientos.",
                              revertibles: acciones),
            householdId: hogar, userId: usuario
        )
        let leida = await svc.loadCurrent(householdId: hogar, userId: usuario)
        XCTAssertEqual(leida.messages.first?.revertibles?.count, 13)
    }

    /// Un mensaje sin acciones no guarda un array vacío: no ensucia el JSON del
    /// historial, que se lee entero en cada apertura.
    func testUnMensajeSinAccionesNoGuardaNada() async throws {
        await svc.appendMessage(
            ChatMessageRecord(role: .assistant, content: "Gastaste 174.050 este mes."),
            householdId: hogar, userId: usuario
        )
        let leida = await svc.loadCurrent(householdId: hogar, userId: usuario)
        XCTAssertNil(leida.messages.first?.revertibles)
    }

    /// El caso que rompe historiales: un mensaje guardado ANTES de que el campo
    /// existiera. Si la decodificación fallara, el chat entero deja de cargar.
    func testUnMensajeViejoSinElCampoSigueDecodificando() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "role": "assistant",
          "content": "Cargué el gasto.",
          "timestamp": "2026-08-01T12:00:00Z",
          "hadAttachment": false
        }
        """.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let rec = try dec.decode(ChatMessageRecord.self, from: json)
        XCTAssertEqual(rec.content, "Cargué el gasto.")
        XCTAssertNil(rec.revertibles)
    }
}
