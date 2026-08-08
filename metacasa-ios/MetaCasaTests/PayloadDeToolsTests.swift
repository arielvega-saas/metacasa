import XCTest
@testable import Home_Finance

/// Lo que sale por el cable cuando le mandamos las herramientas a Claude.
///
/// El asistente venía afirmando cargas que nunca ocurrían, y el sello de
/// diagnóstico en el device confirmó que el turno pasaba por el camino CON loop
/// de tools y aun así terminaba en `escrituras: 0`: el modelo respondía texto y
/// nunca pedía la herramienta. Antes de culpar al modelo hay que descartar lo
/// más barato — que el payload salga malformado y Anthropic lo ignore.
final class PayloadDeToolsTests: XCTestCase {

    private func payload() throws -> [[String: Any]] {
        let data = try JSONEncoder().encode(AnthropicToolBuilder.allTools())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }

    func testSeMandanLas22Herramientas() throws {
        XCTAssertEqual(try payload().count, 22)
    }

    /// La forma que exige la API: `name`, `description` e `input_schema`
    /// (snake_case). Si el nombre de la clave sale mal, el modelo no ve nada.
    func testCadaHerramientaTieneLaFormaQueExigeLaAPI() throws {
        for tool in try payload() {
            let nombre = tool["name"] as? String
            XCTAssertNotNil(nombre)
            XCTAssertFalse((nombre ?? "").isEmpty)
            XCTAssertFalse((tool["description"] as? String ?? "").isEmpty,
                           "\(nombre ?? "?") sin description: el modelo elige por acá")

            let schema = try XCTUnwrap(tool["input_schema"] as? [String: Any],
                                       "\(nombre ?? "?") sin input_schema")
            XCTAssertEqual(schema["type"] as? String, "object")
            XCTAssertNotNil(schema["properties"] as? [String: Any])
        }
    }

    /// La tool que se venía "ejecutando" sin ejecutarse.
    func testAddTransactionDeclaraSusParametrosObligatorios() throws {
        let tool = try XCTUnwrap(try payload().first { $0["name"] as? String == "add_transaction" })
        let schema = try XCTUnwrap(tool["input_schema"] as? [String: Any])
        let props = try XCTUnwrap(schema["properties"] as? [String: Any])
        let required = try XCTUnwrap(schema["required"] as? [String])

        for campo in ["amount", "category", "type"] {
            XCTAssertNotNil(props[campo], "falta la propiedad \(campo)")
            XCTAssertTrue(required.contains(campo), "\(campo) debería ser obligatorio")
        }
        // El tipo de `amount` importa: si sale como string, el modelo manda
        // "1000000" y el parseo del monto queda a merced del formato.
        let amount = try XCTUnwrap(props["amount"] as? [String: Any])
        XCTAssertEqual(amount["type"] as? String, "number")
    }

    func testUpdateYDeletePidenElIdDelMovimiento() throws {
        for nombre in ["update_transaction", "delete_transaction"] {
            let tool = try XCTUnwrap(try payload().first { $0["name"] as? String == nombre })
            let schema = try XCTUnwrap(tool["input_schema"] as? [String: Any])
            let required = try XCTUnwrap(schema["required"] as? [String])
            XCTAssertTrue(required.contains("transactionId"), "\(nombre) sin transactionId obligatorio")
        }
    }

    /// Los nombres no pueden repetirse ni traer caracteres que la API rechace.
    func testLosNombresSonUnicosYValidos() throws {
        let nombres = try payload().compactMap { $0["name"] as? String }
        XCTAssertEqual(Set(nombres).count, nombres.count, "hay nombres repetidos")
        for n in nombres {
            XCTAssertTrue(n.allSatisfy { $0.isLowercase || $0 == "_" || $0.isNumber },
                          "nombre inválido: \(n)")
        }
    }
}
