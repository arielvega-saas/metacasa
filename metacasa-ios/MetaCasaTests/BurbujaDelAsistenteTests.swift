import XCTest
@testable import Home_Finance

/// Clasificación del feedback y textos nuevos de la burbuja.
final class BurbujaDelAsistenteTests: XCTestCase {

    // MARK: - Clasificar el voto

    /// Interesa distinguir "responde mal las consultas" de "carga mal los
    /// movimientos": son dos problemas con dos arreglos distintos.
    func testUnaConfirmacionDeAccionSeClasificaAparte() {
        XCTAssertEqual(AssistantFeedbackLog.clasificar("✅ Gasto cargado: ARS 12.500 en Alimentos."),
                       .confirmacion)
        XCTAssertEqual(AssistantFeedbackLog.clasificar("⚠️ No pude cargarlo."), .confirmacion)
        XCTAssertEqual(AssistantFeedbackLog.clasificar("❌ Error al actualizar."), .confirmacion)
    }

    func testUnListadoSeClasificaComoListado() {
        let listado = """
        Encontré 4 movimientos:
        • 05/08: ARS 45.320 Alimentos
        • 05/08: ARS 38.000 Transporte
        • 06/08: ARS 2.800 Otros
        """
        XCTAssertEqual(AssistantFeedbackLog.clasificar(listado), .listado)
    }

    func testUnaRespuestaNormalNoEsListado() {
        XCTAssertEqual(AssistantFeedbackLog.clasificar("Gastaste 174.050 este mes, 12% arriba del promedio."),
                       .respuesta)
    }

    /// Dos viñetas no alcanzan: una respuesta con un par de aclaraciones sigue
    /// siendo una respuesta.
    func testDosVinetasSiguenSiendoRespuesta() {
        XCTAssertEqual(AssistantFeedbackLog.clasificar("Ojo con esto:\n• una cosa\n• otra"), .respuesta)
    }

    // MARK: - Los textos resuelven de verdad

    /// Un `Text("clave")` cuya clave no está en el catálogo muestra **la clave
    /// cruda** en pantalla, en todos los idiomas. Ya pasó antes, así que el
    /// test no mira el `.xcstrings` —que ni siquiera viaja al bundle: se
    /// compila a `.strings` por idioma— sino la resolución real.
    func testLasClavesNuevasResuelven() {
        for clave in ["assistant.showMore", "assistant.showLess", "assistant.copy",
                      "assistant.helpful", "assistant.notHelpful", "assistant.disclaimer",
                      "assistant.history.title", "assistant.history.resume",
                      "assistant.history.empty.title", "assistant.history.empty.body",
                      "assistant.newConversation", "common.close"] {
            let resuelto = String(localized: String.LocalizationValue(clave))
            XCTAssertNotEqual(resuelto, clave,
                              "\(clave) no resuelve: se mostraría el identificador crudo")
            XCTAssertFalse(resuelto.isEmpty)
        }
    }

    /// El aviso de IA tiene que decir las dos cosas: que puede equivocarse y
    /// que no es asesoramiento financiero.
    func testElAvisoDeIADiceLoQueTieneQueDecir() {
        let aviso = String(localized: "assistant.disclaimer").lowercased()
        XCTAssertTrue(aviso.contains("equivocar") || aviso.contains("mistake"))
        XCTAssertTrue(aviso.contains("asesoramiento") || aviso.contains("advice"))
    }
}
