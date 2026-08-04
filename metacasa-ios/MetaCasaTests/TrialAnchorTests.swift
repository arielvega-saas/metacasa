import XCTest
@testable import Home_Finance

/// Tests del ancla del trial.
///
/// Existen porque `trialStartDate()` llamaba a `AppTransaction.shared` en **cada arranque**.
/// `AppTransaction.shared` es interactivo: si el dispositivo no tiene sesión de App Store,
/// StoreKit abre "Iniciar sesión en cuenta de Apple". Como se llamaba siempre, cancelar el
/// diálogo lo hacía volver, en loop, con la app trabada en el splash detrás. Se descubrió
/// intentando usar la app en el simulador para sacar los screenshots de tienda, pero le pasa
/// a cualquier usuario cuya sesión de App Store no esté iniciada.
///
/// La garantía que estos tests protegen: **con ancla ya guardada, el arranque no toca StoreKit.**
final class TrialAnchorTests: XCTestCase {

    /// El ancla real del simulador donde corren los tests, para no dejarla pisada.
    private var anclaPrevia: String?

    override func setUp() {
        super.setUp()
        anclaPrevia = KeychainStore.get(TrialManager.keychainKey)
    }

    override func tearDown() {
        if let anclaPrevia {
            KeychainStore.set(anclaPrevia, for: TrialManager.keychainKey)
        } else {
            KeychainStore.delete(TrialManager.keychainKey)
        }
        super.tearDown()
    }

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func sembrarAncla(diasAtras: Double) -> Date {
        let fecha = Date().addingTimeInterval(-diasAtras * 86_400)
        // Se guarda por el mismo camino que lee la app: ida y vuelta por ISO8601, así el
        // test no puede pasar por una fecha que la app no sabría parsear.
        KeychainStore.set(Self.iso.string(from: fecha), for: TrialManager.keychainKey)
        return Self.iso.date(from: Self.iso.string(from: fecha))!
    }

    // MARK: - El ancla guardada manda

    func testUsaElAnclaGuardada() async {
        let sembrada = sembrarAncla(diasAtras: 3)
        let leida = await TrialManager.trialStartDate()
        XCTAssertEqual(leida.timeIntervalSince1970, sembrada.timeIntervalSince1970, accuracy: 1)
    }

    /// El test que da la garantía de fondo: con ancla guardada, resolver el trial es
    /// instantáneo. Si volviera a consultar StoreKit tardaría los 4 s del timeout de
    /// `AppTransaction` — o abriría el diálogo de login y colgaría el test.
    func testConAnclaGuardadaNoConsultaStoreKit() async {
        _ = sembrarAncla(diasAtras: 1)
        let inicio = Date()
        _ = await TrialManager.trialStartDate()
        let tardo = Date().timeIntervalSince(inicio)
        XCTAssertLessThan(tardo, 1.0, "Resolver el trial con ancla guardada no debe tocar StoreKit")
    }

    /// Dos arranques seguidos tienen que ver el mismo ancla: si se re-anclara, el trial
    /// se renovaría solo y la app nunca se bloquearía.
    func testElAnclaNoSeMueveEntreArranques() async {
        _ = sembrarAncla(diasAtras: 5)
        let primero = await TrialManager.trialStartDate()
        let segundo = await TrialManager.trialStartDate()
        XCTAssertEqual(primero, segundo)
    }

    // MARK: - Vigencia

    func testTrialVigenteConAnclaDeHoy() async {
        _ = sembrarAncla(diasAtras: 0)
        let vigente = await TrialManager.isInTrial()
        let dias = await TrialManager.daysRemaining()
        XCTAssertTrue(vigente)
        XCTAssertEqual(dias, 7)
    }

    func testUltimoDiaSigueVigente() async {
        _ = sembrarAncla(diasAtras: 6.5)
        let vigente = await TrialManager.isInTrial()
        let dias = await TrialManager.daysRemaining()
        XCTAssertTrue(vigente, "A los 6 días y medio el trial todavía corre")
        XCTAssertEqual(dias, 1, "Medio día restante se muestra como 1, nunca como 0")
    }

    func testTrialVencidoConAnclaVieja() async {
        _ = sembrarAncla(diasAtras: 8)
        let vigente = await TrialManager.isInTrial()
        let dias = await TrialManager.daysRemaining()
        XCTAssertFalse(vigente)
        XCTAssertEqual(dias, 0)
    }

    /// Justo en el borde: a los 7 días exactos ya venció.
    func testAJustoSieteDiasYaVencio() async {
        _ = sembrarAncla(diasAtras: 7.001)
        let vigente = await TrialManager.isInTrial()
        XCTAssertFalse(vigente)
    }

    // MARK: - Persistencia

    /// Sin ancla previa, la primera resolución tiene que dejarla escrita. Si no quedara
    /// escrita, el arranque siguiente volvería a preguntarle a StoreKit — que es el bug.
    func testSinAnclaPreviaLaPersiste() async {
        KeychainStore.delete(TrialManager.keychainKey)
        XCTAssertNil(TrialManager.storedAnchor(), "Precondición: sin ancla")

        _ = await TrialManager.trialStartDate()

        XCTAssertNotNil(TrialManager.storedAnchor(), "La primera resolución tiene que persistir el ancla")
    }
}
