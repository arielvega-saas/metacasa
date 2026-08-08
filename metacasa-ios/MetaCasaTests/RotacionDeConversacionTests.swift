import XCTest
@testable import Home_Finance

/// Cuándo el asistente tiene que arrancar de cero.
///
/// Caso real: Ariel cerraba la app, volvía a abrir el asistente y se encontraba
/// con la conversación anterior en vez de la bienvenida con sugerencias. El
/// cierre de sesión colgaba de `onDisappear`, que **no corre si matás la app**
/// desde el chat: la conversación quedaba abierta para siempre y su resumen
/// —la memoria del asistente entre charlas— nunca se generaba.
///
/// La regla pasa a ser el tiempo, no el ciclo de vida de la vista.
final class RotacionDeConversacionTests: XCTestCase {

    private let hogar = UUID()
    private let usuario = UUID()
    private let svc = ChatPersistenceService.shared

    override func setUp() async throws {
        await svc.clearAll(householdId: hogar)
    }

    override func tearDown() async throws {
        await svc.clearAll(householdId: hogar)
    }

    private func sembrar(_ cuantos: Int) async {
        for i in 0..<cuantos {
            await svc.appendMessage(
                ChatMessageRecord(role: i.isMultiple(of: 2) ? .user : .assistant,
                                  content: "mensaje \(i)"),
                householdId: hogar, userId: usuario
            )
        }
    }

    // MARK: - La ventana de continuidad

    func testVolverEnElMomentoRetomaLaMismaConversacion() async {
        await sembrar(6)
        let rotada = await svc.rotar(householdId: hogar, userId: usuario, soloSiVencio: true)
        XCTAssertNil(rotada, "recién hablado: no se rota")

        let actual = await svc.loadCurrent(householdId: hogar, userId: usuario)
        XCTAssertEqual(actual.messages.count, 6, "y la conversación sigue entera")
    }

    func testVolverAlOtroDiaEmpiezaUnaNueva() async {
        await sembrar(6)
        let manana = Date().addingTimeInterval(24 * 3600)
        let vieja = await svc.rotar(householdId: hogar, userId: usuario,
                                    soloSiVencio: true, ahora: manana)

        XCTAssertNotNil(vieja, "devuelve la vieja para poder resumirla")
        XCTAssertEqual(vieja?.messages.count, 6)
        XCTAssertTrue(vieja?.isClosed == true)

        let actual = await svc.loadCurrent(householdId: hogar, userId: usuario)
        XCTAssertTrue(actual.messages.isEmpty, "y la pantalla arranca limpia")
        XCTAssertNotEqual(actual.id, vieja?.id, "es otra sesión, no la misma vaciada")
    }

    /// El corte exacto importa: media hora es continuidad, media hora y un
    /// segundo ya es otra charla.
    func testElBordeDeLaVentana() async {
        await sembrar(6)
        // El borde se mide desde el último mensaje, no desde "ahora": sembrar
        // tarda unos milisegundos y con `Date()` el test quedaba del lado de
        // afuera de la ventana por accidente.
        let ultimo = await svc.loadCurrent(householdId: hogar, userId: usuario).lastUpdatedAt
        let justo = ultimo.addingTimeInterval(ChatPersistenceService.ventanaDeContinuidad)
        let sinRotar = await svc.rotar(householdId: hogar, userId: usuario,
                                       soloSiVencio: true, ahora: justo)
        XCTAssertNil(sinRotar, "justo en el límite todavía es la misma")

        let apenasDespues = justo.addingTimeInterval(1)
        let rotada = await svc.rotar(householdId: hogar, userId: usuario,
                                     soloSiVencio: true, ahora: apenasDespues)
        XCTAssertNotNil(rotada)
    }

    // MARK: - Lo que no hay que romper

    func testUnaConversacionVaciaNoRota() async {
        let manana = Date().addingTimeInterval(24 * 3600)
        let rotada = await svc.rotar(householdId: hogar, userId: usuario,
                                     soloSiVencio: true, ahora: manana)
        XCTAssertNil(rotada, "sin mensajes no hay nada que archivar ni que resumir")
    }

    func testEmpezarDeNuevoAManoRotaAunqueSeaReciente() async {
        await sembrar(6)
        let vieja = await svc.rotar(householdId: hogar, userId: usuario, soloSiVencio: false)
        XCTAssertNotNil(vieja)

        let actual = await svc.loadCurrent(householdId: hogar, userId: usuario)
        XCTAssertTrue(actual.messages.isEmpty)
    }

    /// Rotar no puede perder la conversación: se archiva antes de crear la
    /// nueva, así el resumen se genera después sin correr contra el usuario.
    func testLaConversacionRotadaSobreviveParaResumirse() async {
        await sembrar(8)
        let manana = Date().addingTimeInterval(24 * 3600)
        let vieja = await svc.rotar(householdId: hogar, userId: usuario,
                                    soloSiVencio: true, ahora: manana)
        XCTAssertEqual(vieja?.messages.count, 8)
        XCTAssertEqual(vieja?.householdId, hogar)
    }

    /// Una charla trivial no ensucia la memoria del asistente.
    func testUnaCharlaCortaNoGeneraResumen() async {
        await sembrar(3)
        let manana = Date().addingTimeInterval(24 * 3600)
        let vieja = await svc.rotar(householdId: hogar, userId: usuario,
                                    soloSiVencio: true, ahora: manana)
        XCTAssertNotNil(vieja, "igual se rota: la pantalla tiene que arrancar limpia")

        // Sin token no hay request; lo que se verifica es que no explote y que
        // el índice de memoria quede vacío para una charla de 3 mensajes.
        await svc.resumirEIndexar(vieja!, accessToken: nil)
        let resumenes = await svc.recentSummaries(householdId: hogar, limit: 3)
        XCTAssertTrue(resumenes.isEmpty)
    }
}
