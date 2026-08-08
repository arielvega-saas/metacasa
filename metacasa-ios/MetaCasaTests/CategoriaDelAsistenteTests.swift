import XCTest
@testable import Home_Finance

/// La categoría que el asistente escribe tiene que existir en la app.
///
/// El modelo la manda como texto libre. Si inventa una que no está en el
/// catálogo del hogar, el movimiento se guarda igual pero queda **huérfano**:
/// no aparece en el selector al editarlo, no se puede presupuestar, y en los
/// reportes es una categoría de una sola fila. Verificado en la base del
/// usuario: cinco movimientos con "Comida hecha", "Celular" y "Seguro", ninguna
/// de las tres en su catálogo.
final class CategoriaDelAsistenteTests: XCTestCase {

    /// El catálogo efectivo es defaults + custom, no sólo lo que hay guardado.
    /// Mirar únicamente el blob da falsos "no existe".
    func testElCatalogoUneLosDefaultsConLosDelHogar() {
        let custom = CategoriesData(
            gastos: [CategoryItem(name: "Supermercado"), CategoryItem(name: "Herramientas")],
            ingresos: []
        )
        let nombres = CategoryService.merged(custom: custom, type: .gasto).map(\.name)

        XCTAssertTrue(nombres.contains("Alimentación"), "falta un default")
        XCTAssertTrue(nombres.contains("Supermercado"), "falta una del hogar")
        XCTAssertTrue(nombres.contains("Herramientas"))
    }

    func testUnaCategoriaDelHogarNoSeDuplicaConElDefault() {
        let custom = CategoriesData(
            gastos: [CategoryItem(name: "Salud", emoji: "🩺")],
            ingresos: []
        )
        let nombres = CategoryService.merged(custom: custom, type: .gasto).map(\.name)
        XCTAssertEqual(nombres.filter { $0 == "Salud" }.count, 1)
    }

    /// El modelo escribe sin tildes muy seguido. "alimentacion" tiene que
    /// resolver a "Alimentación" y no crear una categoría nueva casi idéntica.
    func testNormalizarIgnoraTildesYMayusculas() {
        let normalizar: (String) -> String = { s in
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespaces)
        }
        XCTAssertEqual(normalizar("alimentacion"), normalizar("Alimentación"))
        XCTAssertEqual(normalizar("EDUCACIÓN"), normalizar("educacion"))
        XCTAssertEqual(normalizar(" Ocio "), normalizar("ocio"))
        XCTAssertNotEqual(normalizar("Salud"), normalizar("Saludo"))
    }

    /// Una categoría nueva se agrega al lado de las que ya estaban, sin pisarlas.
    func testAgregarUnaCategoriaConservaLasAnteriores() {
        var data = CategoriesData(
            gastos: [CategoryItem(name: "Supermercado")],
            ingresos: [CategoryItem(name: "Sueldo")]
        )
        data.gastos.append(CategoryItem(name: "Mascotas", emoji: CategoryCatalog.emoji(for: "Mascotas")))

        XCTAssertEqual(data.gastos.map(\.name), ["Supermercado", "Mascotas"])
        XCTAssertEqual(data.ingresos.map(\.name), ["Sueldo"], "los ingresos no se tocan")
    }

    /// Un ingreso no puede terminar en la lista de gastos.
    func testUnIngresoVaALaListaDeIngresos() {
        let nombres = CategoryService.merged(custom: nil, type: .ingreso).map(\.name)
        XCTAssertTrue(nombres.contains("Sueldo"))
        XCTAssertFalse(nombres.contains("Vivienda"), "eso es un gasto")
    }
}
