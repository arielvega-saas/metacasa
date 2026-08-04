import XCTest
@testable import Home_Finance

/// Tolerancia a valores de enum que esta versión no conoce.
///
/// El backend es compartido con la web. Sin esto, un tipo de cuenta nuevo creado
/// desde la web le tiraría el decodificador a la app publicada — y no pierde la
/// fila rara: **pierde la respuesta entera**, así que el usuario abre la app y no
/// ve NINGUNA cuenta. Es lo que ya obligó a descartar el tipo `TRANSFERENCIA` en
/// las transacciones (`AUDITORIA-2026-08-01.md`).
final class UnknownTolerantDecodableTests: XCTestCase {

    private func decodeType(_ raw: String) throws -> AccountType {
        let json = Data("\"\(raw)\"".utf8)
        return try JSONDecoder().decode(AccountType.self, from: json)
    }

    func testDecodificaLosValoresConocidos() throws {
        XCTAssertEqual(try decodeType("checking"), .checking)
        XCTAssertEqual(try decodeType("savings"), .savings)
        XCTAssertEqual(try decodeType("credit_card"), .creditCard)
        XCTAssertEqual(try decodeType("other"), .other)
    }

    /// El caso que importa: un tipo que esta versión no conoce todavía.
    func testUnValorDesconocidoCaeEnOtherYNoTira() throws {
        XCTAssertEqual(try decodeType("wallet"), .other)
        XCTAssertEqual(try decodeType("crypto"), .other)
        XCTAssertEqual(try decodeType(""), .other)
    }

    /// La garantía de fondo: la lista COMPLETA sobrevive a un valor desconocido.
    /// Antes, la cuenta rara se llevaba puestas también a las buenas.
    func testUnaCuentaDesconocidaNoSeLlevaPuestasALasDemas() throws {
        let json = Data("""
        ["checking", "wallet", "savings"]
        """.utf8)

        let tipos = try JSONDecoder().decode([AccountType].self, from: json)

        XCTAssertEqual(tipos.count, 3, "Ninguna se pierde")
        XCTAssertEqual(tipos, [.checking, .other, .savings])
    }
}
