import XCTest
@testable import Home_Finance

/// El asistente confirmó por escrito un cambio que nunca ocurrió.
///
/// Caso real (07/08/2026): Ariel pidió corregir un gasto de $98.800 a
/// $78.972,57. El asistente respondió "✓ Corregido. Higgsfield Inc. ahora está
/// en $78.972,57". En la base el registro seguía en 98.800 y su `updated_at`
/// era idéntico al `created_at`: **nunca se escribió**.
///
/// Dos fallas encadenadas:
///
/// 1. Los listados devolvían el id recortado a 8 caracteres y el "expansor" era
///    `if s.count == 8 { return s }; return s` —una función que no hace nada—.
///    `UUID(uuidString: "b3deed5d")` es `nil`, así que **editar y borrar desde
///    el chat nunca funcionó**: el modelo no tenía forma de conocer otro id.
/// 2. El fallo se devolvía como texto (`"Error: invalid transaction ID
///    format."`) en un `tool_result` exitoso, y el modelo lo ignoró.
///
/// Estos tests cubren la primera. La segunda vive en `AnthropicProvider`
/// (`is_error: true`) y en que las tools lancen.
final class EdicionDesdeElAsistenteTests: XCTestCase {

    /// La regresión exacta: un id recortado no puede parsearse como UUID.
    /// Si esto vuelve a ser la única vía, editar vuelve a estar roto.
    func testUnIdRecortadoNoEsUnUUID() {
        let completo = UUID(uuidString: "b3deed5d-c93a-40b4-9d3e-b98914763888")!
        let recortado = String(completo.uuidString.prefix(8))
        XCTAssertEqual(recortado, "B3DEED5D")
        XCTAssertNil(UUID(uuidString: recortado),
                     "8 caracteres NO son un UUID: por acá se perdían todas las ediciones")
        XCTAssertNotNil(UUID(uuidString: completo.uuidString))
    }

    /// Un prefijo identifica un movimiento sólo si es único. Con menos de 6
    /// caracteres el riesgo es editar el movimiento equivocado, que es peor que
    /// fallar.
    func testElPrefijoTieneQueSerUnicoParaIdentificar() {
        let a = UUID(uuidString: "b3deed5d-c93a-40b4-9d3e-b98914763888")!
        let b = UUID(uuidString: "b3deed5d-0000-0000-0000-000000000000")!
        let prefijo = "b3deed5d"
        let coinciden = [a, b].filter { $0.uuidString.lowercased().hasPrefix(prefijo) }
        XCTAssertEqual(coinciden.count, 2, "el mismo prefijo puede pertenecer a dos movimientos")
    }

    // MARK: - Los errores tienen que sonar a error

    /// El texto que ve el modelo debe prohibir explícitamente informar el
    /// cambio. "Error: transaction not found." no alcanzó.
    func testLosErroresLeDicenAlModeloQueNoInformeElCambio() {
        let casos: [AIToolError] = [
            .movimientoNoEncontrado("b3deed5d"),
            .escrituraNoVerificable(UUID().uuidString),
            .escrituraNoImpactada(pedido: "ARS 78.972 en Herramientas",
                                  real: "ARS 98.800 en Herramientas"),
        ]
        for caso in casos {
            let texto = caso.errorDescription ?? ""
            XCTAssertTrue(texto.contains("NO informes"),
                          "el error tiene que instruir explícitamente: \(texto)")
        }
    }

    func testUnaReferenciaInvalidaPideBuscarDeNuevo() {
        let texto = AIToolError.referenciaInvalida("higgsfield").errorDescription ?? ""
        XCTAssertTrue(texto.contains("id completo"))
    }

    func testUnaReferenciaAmbiguaDiceCuantasCoincidieron() {
        let texto = AIToolError.referenciaAmbigua("b3deed5d", 2).errorDescription ?? ""
        XCTAssertTrue(texto.contains("2"))
    }

    // MARK: - is_error viaja al modelo

    func testUnToolResultFallidoSeCodificaConIsError() throws {
        let bloque = APIBlock(type: "tool_result", toolUseId: "tu_1",
                              content: "La herramienta falló", isError: true)
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(bloque)) as? [String: Any]
        XCTAssertEqual(json?["is_error"] as? Bool, true,
                       "sin is_error el modelo trata el fallo como un dato más")
    }

    /// Un resultado exitoso no debe llevar la marca: si todo fuera `is_error`,
    /// la señal dejaría de significar algo.
    func testUnToolResultOkNoLlevaLaMarca() throws {
        let bloque = APIBlock(type: "tool_result", toolUseId: "tu_1", content: "ok")
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(bloque)) as? [String: Any]
        XCTAssertNil(json?["is_error"])
    }
}
