import XCTest
@testable import Home_Finance

/// El widget se ve en la pantalla de inicio de alguien que puso el iPhone en
/// inglés o en portugués.
///
/// Estaba enteramente hardcodeado en español —"Balance del mes", "Próximo",
/// "Abrí la app para ver tu balance"— y encima el catálogo de textos ni
/// siquiera formaba parte de su target, así que no había forma de que
/// resolviera. Es la pantalla más visible de la app y la única que se ve sin
/// abrirla.
final class TextosDelWidgetTests: XCTestCase {

    private let claves = [
        "widget.balance", "widget.next", "widget.today",
        "widget.empty", "widget.displayName", "widget.description",
    ]

    /// Una clave que no resuelve muestra el identificador crudo en pantalla.
    func testLasClavesDelWidgetResuelven() {
        for clave in claves {
            let resuelto = String(localized: String.LocalizationValue(clave))
            XCTAssertNotEqual(resuelto, clave, "\(clave) no resuelve")
            XCTAssertFalse(resuelto.isEmpty)
        }
    }

    /// "En 1 días" es el error clásico. El plural tiene que estar declarado, y
    /// eso sólo se ve interpolando de verdad.
    func testElContadorDeDiasUsaPlural() {
        // La clave real incluye el especificador: un Int interpolado busca
        // `%lld`, no el nombre pelado. Es el mismo error que ya nos costó una
        // pantalla mostrando el identificador crudo.
        let uno = String(localized: "widget.inDays \(1)")
        let varios = String(localized: "widget.inDays \(5)")

        XCTAssertNotEqual(uno, varios)
        XCTAssertFalse(uno.contains("widget.inDays"), "no resolvió: \(uno)")
        XCTAssertTrue(uno.contains("1"))
        XCTAssertTrue(varios.contains("5"))
        // La forma singular no puede terminar en "días".
        XCTAssertFalse(uno.lowercased().contains("días"), "singular mal formado: \(uno)")
    }

    /// El texto del widget vive en un espacio muy chico: si es largo, se
    /// trunca y no se entiende.
    func testLosTextosDelWidgetSonCortos() {
        for clave in ["widget.balance", "widget.next", "widget.today"] {
            let resuelto = String(localized: String.LocalizationValue(clave))
            XCTAssertLessThanOrEqual(resuelto.count, 12, "\(clave) es muy largo para el widget: \(resuelto)")
        }
    }
}
