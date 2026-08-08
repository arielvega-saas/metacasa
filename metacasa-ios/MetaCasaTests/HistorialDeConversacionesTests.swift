import XCTest
@testable import Home_Finance

/// El historial de conversaciones.
///
/// Las charlas ya se archivaban y se resumían, pero no había forma de verlas:
/// desde que el chat arranca limpio pasada la media hora, una conversación
/// vieja quedaba en disco e inalcanzable para el usuario.
final class HistorialDeConversacionesTests: XCTestCase {

    private let hogar = UUID()
    private let usuario = UUID()
    private let svc = ChatPersistenceService.shared

    override func setUp() async throws { await svc.clearAll(householdId: hogar) }
    override func tearDown() async throws { await svc.clearAll(householdId: hogar) }

    private func sembrarYArchivar(_ textos: [String], cerradaEn: Date = Date()) async -> UUID? {
        for (i, texto) in textos.enumerated() {
            await svc.appendMessage(
                ChatMessageRecord(role: i.isMultiple(of: 2) ? .user : .assistant, content: texto),
                householdId: hogar, userId: usuario
            )
        }
        return await svc.rotar(householdId: hogar, userId: usuario,
                               soloSiVencio: false, ahora: cerradaEn)?.id
    }

    func testUnaConversacionArchivadaAparaceEnElHistorial() async {
        _ = await sembrarYArchivar(["cargá los gastos del finde", "listo", "gracias", "de nada"])
        let lista = await svc.conversacionesArchivadas(householdId: hogar)
        XCTAssertEqual(lista.count, 1)
        XCTAssertEqual(lista.first?.mensajes, 4)
    }

    /// El título es el primer mensaje del usuario: uno reconoce "cargá los
    /// gastos del finde" mucho antes que una fecha.
    func testElTituloEsElPrimerMensajeDelUsuario() async {
        _ = await sembrarYArchivar(["cargá los gastos del finde", "listo"])
        let lista = await svc.conversacionesArchivadas(householdId: hogar)
        XCTAssertEqual(lista.first?.titulo, "cargá los gastos del finde")
    }

    func testUnTituloLargoSeRecorta() async {
        let largo = String(repeating: "gasto de supermercado ", count: 20)
        _ = await sembrarYArchivar([largo, "ok"])
        let titulo = await svc.conversacionesArchivadas(householdId: hogar).first?.titulo ?? ""
        XCTAssertLessThanOrEqual(titulo.count, 71)
        XCTAssertTrue(titulo.hasSuffix("…"))
    }

    func testLasMasRecientesVanPrimero() async {
        let base = Date()
        _ = await sembrarYArchivar(["primera", "ok"], cerradaEn: base)
        _ = await sembrarYArchivar(["segunda", "ok"], cerradaEn: base.addingTimeInterval(60))
        let lista = await svc.conversacionesArchivadas(householdId: hogar)
        XCTAssertEqual(lista.count, 2)
        XCTAssertEqual(lista.first?.titulo, "segunda")
    }

    func testSinConversacionesDevuelveVacio() async {
        let lista = await svc.conversacionesArchivadas(householdId: hogar)
        XCTAssertTrue(lista.isEmpty)
    }

    // MARK: - Retomar

    func testRetomarDejaLaConversacionElegidaComoLaActual() async {
        guard let vieja = await sembrarYArchivar(["hablemos de deudas", "dale"]) else {
            return XCTFail("no se archivó")
        }
        let retomada = await svc.retomar(householdId: hogar, userId: usuario, sessionId: vieja)
        XCTAssertEqual(retomada?.id, vieja)

        let actual = await svc.loadCurrent(householdId: hogar, userId: usuario)
        XCTAssertEqual(actual.id, vieja)
        XCTAssertEqual(actual.messages.first?.content, "hablemos de deudas")
        XCTAssertFalse(actual.isClosed, "vuelve a estar abierta para poder seguir escribiendo")
    }

    /// Retomar no puede hacerte perder lo que venías hablando.
    func testRetomarArchivaLaConversacionEnCurso() async {
        guard let vieja = await sembrarYArchivar(["conversación vieja", "ok"]) else {
            return XCTFail("no se archivó")
        }
        // Una charla nueva en curso.
        await svc.appendMessage(ChatMessageRecord(role: .user, content: "lo de ahora"),
                                householdId: hogar, userId: usuario)

        _ = await svc.retomar(householdId: hogar, userId: usuario, sessionId: vieja)

        let lista = await svc.conversacionesArchivadas(householdId: hogar)
        XCTAssertTrue(lista.contains { $0.titulo == "lo de ahora" },
                      "la que estaba en curso tiene que quedar archivada, no perderse")
    }

    func testRetomarAlgoQueNoExisteNoRompe() async {
        let r = await svc.retomar(householdId: hogar, userId: usuario, sessionId: UUID())
        XCTAssertNil(r)
    }
}
