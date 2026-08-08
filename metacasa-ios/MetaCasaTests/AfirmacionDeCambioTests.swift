import XCTest
@testable import Home_Finance

/// El asistente afirmando cambios que no hizo.
///
/// Caso real (07/08/2026): "Actualicé el gasto a 78.972,57 pesos en
/// Herramientas. Tu balance del mes queda en 2.591.362,43 pesos." En la base el
/// gasto seguía en 98.800 y su `updated_at` era idéntico al `created_at`.
/// El balance informado tampoco salía de ninguna cuenta: la corrección habría
/// movido $19.827 y el número que dio se movió $145.
///
/// El detector es la mitad del guardrail; la otra mitad es el contador de
/// escrituras reales del turno. Afirmación + cero escrituras = el turno no se
/// muestra como un hecho.
final class AfirmacionDeCambioTests: XCTestCase {

    private func afirma(_ t: String) -> Bool { AfirmacionDeCambio.afirmaCambio(t) }

    // MARK: - Lo que hay que atajar

    func testElCasoRealQueMotivoElGuardrail() {
        XCTAssertTrue(afirma("Actualicé el gasto a 78.972,57 pesos en Herramientas. Tu balance del mes queda en 2.591.362,43 pesos."))
    }

    func testLasFormasDeDecirQueYaSeHizo() {
        for texto in [
            "Listo, cargué los 13 movimientos.",
            "Ya está actualizado el gasto de Herramientas.",
            "Borré la transacción duplicada.",
            "Transferí 50.000 de Caja de ahorro a Efectivo.",
            "El gasto quedó corregido a 78.972,57.",
            "Marqué la factura como pagada.",
            "Agregué el gasto de nafta.",
            "Seteé el presupuesto de Alimentos en 200.000.",
        ] {
            XCTAssertTrue(afirma(texto), "debería detectarse: \(texto)")
        }
    }

    /// Sin tilde también: el modelo escribe "cargue" y "actualice" seguido.
    func testSinTildesTambien() {
        XCTAssertTrue(afirma("Listo, cargue el gasto."))
        XCTAssertTrue(afirma("Ya lo actualice."))
    }

    // MARK: - Lo que NO puede disparar (falsos positivos)

    func testPreguntarNoEsAfirmar() {
        for texto in [
            "¿Querés que lo cargue?",
            "¿Confirmás que lo actualizo a ese monto exacto?",
            "Decime la fecha y lo cargo.",
            "Puedo corregirlo si me pasás el número.",
            "Voy a buscar el movimiento.",
            "Necesito más contexto para identificar cuál gasto corregir.",
        ] {
            XCTAssertFalse(afirma(texto), "no debería detectarse: \(texto)")
        }
    }

    func testFallarNoEsAfirmar() {
        for texto in [
            "No pude cargarlo porque falta la categoría.",
            "No encontré ningún movimiento con ese id.",
            "Hubo un error al actualizar el gasto.",
            "El cambio no se aplicó.",
        ] {
            XCTAssertFalse(afirma(texto), "no debería detectarse: \(texto)")
        }
    }

    func testUnaRespuestaDeSoloLecturaNoAfirmaNada() {
        XCTAssertFalse(afirma("Gastaste 174.050,50 este mes, 12% arriba del promedio. La categoría que más subió es Alimentos."))
        XCTAssertFalse(afirma("Tenés 3 vencimientos esta semana: luz, internet y el colegio."))
    }

    // MARK: - Mezclas

    /// Un mensaje puede negar una cosa y afirmar otra. Si afirmó ALGO, el
    /// guardrail tiene que exigir que haya habido escrituras.
    func testSiAfirmaAlgoAunqueNiegueOtraCosaCuenta() {
        XCTAssertTrue(afirma("No pude borrar el duplicado, pero cargué el gasto de nafta."))
    }

    /// Y al revés: negar al final no borra la afirmación previa… pero un
    /// mensaje enteramente negativo no puede dar positivo.
    func testUnMensajeEnteramenteNegativoNoCuenta() {
        XCTAssertFalse(afirma("No pude cargarlo. Tampoco pude actualizar el otro. Decime los datos y lo hago."))
    }

    /// El verbo tiene que ser palabra completa: "cambiemos" no es "cambié".
    func testNoMatcheaDentroDeOtraPalabra() {
        XCTAssertFalse(afirma("Si querés cambiemos la categoría."))
    }

    func testTextoVacio() {
        XCTAssertFalse(afirma(""))
    }
}
