import XCTest
@testable import Home_Finance

/// Tests de la cuenta preseleccionada en el alta de transacción.
///
/// El riesgo que cubren no es elegir "la cuenta equivocada" (el usuario la ve y la cambia), sino
/// devolver un id **colgante**: si apunta a una cuenta borrada, el picker se ve sin selección pero
/// la transacción se inserta contra una FK muerta.
final class DefaultAccountTests: XCTestCase {

    private func account(_ name: String, active: Bool = true) -> Account {
        Account(
            id: UUID(),
            householdId: UUID(),
            name: name,
            type: .checking,
            currency: "ARS",
            startingBalance: 0,
            institution: nil,
            accountNumberLast4: nil,
            icon: nil,
            color: nil,
            displayOrder: 0,
            isActive: active,
            notes: nil,
            ownership: .personal,
            ownerUserId: nil,
            createdBy: UUID(),
            createdAt: nil,
            updatedAt: nil
        )
    }

    func testPrefiereLaUltimaUsada() {
        let a = account("Banco"), b = account("Efectivo")
        let elegida = AddTransactionView.defaultAccountId(from: [a, b], lastUsed: b.id.uuidString)
        XCTAssertEqual(elegida, b.id, "la última usada gana sobre el orden de la lista")
    }

    func testSinUltimaUsadaCaeALaPrimeraActiva() {
        let a = account("Banco"), b = account("Efectivo")
        XCTAssertEqual(AddTransactionView.defaultAccountId(from: [a, b], lastUsed: ""), a.id)
    }

    /// El caso que importa: la cuenta guardada ya no existe.
    func testUltimaUsadaBorradaNoDevuelveUnIdColgante() {
        let a = account("Banco")
        let borrada = UUID().uuidString
        let elegida = AddTransactionView.defaultAccountId(from: [a], lastUsed: borrada)
        XCTAssertEqual(elegida, a.id, "debe caer a una cuenta que EXISTE")
        XCTAssertNotEqual(elegida?.uuidString, borrada)
    }

    func testUltimaUsadaInactivaNoSeElige() {
        let inactiva = account("Vieja", active: false)
        let activa = account("Banco")
        let elegida = AddTransactionView.defaultAccountId(
            from: [inactiva, activa], lastUsed: inactiva.id.uuidString
        )
        XCTAssertEqual(elegida, activa.id)
    }

    func testSoloCuentasInactivasNoEligeNinguna() {
        let inactiva = account("Vieja", active: false)
        XCTAssertNil(AddTransactionView.defaultAccountId(from: [inactiva], lastUsed: ""))
    }

    func testSinCuentasNoEligeNinguna() {
        XCTAssertNil(AddTransactionView.defaultAccountId(from: [], lastUsed: UUID().uuidString))
    }

    func testUuidGuardadoCorruptoNoRompe() {
        let a = account("Banco")
        XCTAssertEqual(AddTransactionView.defaultAccountId(from: [a], lastUsed: "no-es-un-uuid"), a.id)
    }
}
