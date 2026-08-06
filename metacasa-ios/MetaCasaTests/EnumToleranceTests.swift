import XCTest
@testable import Home_Finance

/// Todos los enums de la API toleran valores que esta versión no conoce.
///
/// El backend es compartido entre iOS, la web y Flutter. Un valor nuevo agregado del
/// lado servidor —un tipo de cuenta, un estado de vencimiento— le rompe el
/// decodificador a las versiones ya publicadas, y **no pierde la fila rara: pierde la
/// respuesta entera**. El usuario abre la app y no ve ninguna cuenta, ninguna meta,
/// ningún vencimiento.
///
/// Ya obligó a descartar el tipo `TRANSFERENCIA` en transacciones
/// (`AUDITORIA-2026-08-01.md`) y bloqueó agregar el tipo de cuenta "billetera virtual",
/// que en LatAm es la cuenta principal de mucha gente.
final class EnumToleranceTests: XCTestCase {

    /// Decodifica un valor suelto que el enum no conoce y devuelve a dónde cayó.
    private func decode<T: Decodable>(_ type: T.Type, _ raw: String) throws -> T {
        try JSONDecoder().decode(type, from: Data("\"\(raw)\"".utf8))
    }

    func testValorDesconocidoCaeEnElFallbackDeCadaEnum() throws {
        XCTAssertEqual(try decode(AccountType.self, "wallet"), .other)
        XCTAssertEqual(try decode(AccountOwnership.self, "corporate"), .personal)
        XCTAssertEqual(try decode(GoalStatus.self, "archived"), .active)
        XCTAssertEqual(try decode(BillStatus.self, "disputed"), .pending)
        XCTAssertEqual(try decode(DebtStatus.self, "refinanced"), .active)
        XCTAssertEqual(try decode(InstallmentPlan.PlanStatus.self, "frozen"), .active)
        XCTAssertEqual(try decode(Frequency.self, "fortnightly"), .monthly)
        XCTAssertEqual(try decode(PeriodType.self, "decade"), .month)
        XCTAssertEqual(try decode(RolloverMode.self, "partial"), .none)
        XCTAssertEqual(try decode(SubscriptionStatus.self, "refunded"), .expired)
        XCTAssertEqual(try decode(PeriodKind.self, "winback"), .normal)
        XCTAssertEqual(try decode(SubscriptionEnvironment.self, "staging"), .production)
    }

    func testLosValoresConocidosSiguenDecodificandoBien() throws {
        XCTAssertEqual(try decode(AccountType.self, "credit_card"), .creditCard)
        XCTAssertEqual(try decode(BillStatus.self, "paid"), .paid)
        XCTAssertEqual(try decode(GoalStatus.self, "completed"), .completed)
        XCTAssertEqual(try decode(RolloverMode.self, "surplus"), .surplus)
        XCTAssertEqual(try decode(SubscriptionStatus.self, "grace_period"), .gracePeriod)
    }

    /// Ninguna vía puede regalar acceso: un estado de suscripción que no entendemos
    /// NO cuenta como activo.
    func testUnEstadoDeSuscripcionDesconocidoNoDaAcceso() throws {
        let desconocido = try decode(SubscriptionStatus.self, "some_new_state")
        XCTAssertNotEqual(desconocido, .active)
        XCTAssertNotEqual(desconocido, .trialing)
    }

    /// La garantía que importa: una fila rara no se lleva puestas a las buenas.
    func testUnaFilaDesconocidaNoRompeLaListaEntera() throws {
        let json = Data(#"["pending", "disputed", "paid"]"#.utf8)
        let estados = try JSONDecoder().decode([BillStatus].self, from: json)
        XCTAssertEqual(estados, [.pending, .pending, .paid], "Los 3 sobreviven")
    }

    /// `TxType` queda deliberadamente FUERA: no hay a dónde caer sin mentir. Elegir
    /// entre gasto e ingreso falsearía los totales, así que la respuesta correcta no es
    /// un fallback sino no agregar valores nuevos hasta que la base instalada esté al día.
    func testTxTypeSigueSiendoEstricto() {
        XCTAssertNil(TxType(rawValue: "TRANSFERENCIA"))
        XCTAssertThrowsError(try decode(TxType.self, "TRANSFERENCIA"))
    }
}
