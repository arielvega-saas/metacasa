import XCTest
@testable import Home_Finance

/// Que editar un movimiento no le cambie la categoría.
///
/// El Picker de `EditTransactionView` se armaba con `CategoryCatalog.defaultGastos`
/// / `defaultIngresos` solamente. Un movimiento con categoría propia —creada por
/// el usuario en "Administrar categorías", o puesta por el asistente— no
/// matcheaba ningún `.tag`, así que el Picker salía **sin selección** y el primer
/// toque la reemplazaba. No hay error, no hay aviso: la categoría se pierde al
/// abrir la pantalla y guardar.
///
/// Se ve solo con datos reales: las cuentas de prueba usan categorías del
/// catálogo por defecto, que sí matchean.
final class EditCategoryPickerTests: XCTestCase {

    /// Réplica de `EditTransactionView.categoriasDisponibles`.
    private func disponibles(
        custom: CategoriesData?,
        tipo: TxType,
        actual: String
    ) -> [String] {
        var cats = CategoryService.merged(custom: custom, type: tipo).map(\.name)
        if !cats.contains(actual) { cats.insert(actual, at: 0) }
        return cats
    }

    private func blobConGasto(_ nombre: String) -> CategoriesData {
        CategoriesData(gastos: [CategoryItem(name: nombre)], ingresos: [])
    }

    /// Deja constancia de que el bug era real: la categoría de un hogar de verdad
    /// no tiene por qué estar en el catálogo por defecto.
    func testUnaCategoriaPropiaNoEstaEnElCatalogoPorDefecto() {
        XCTAssertFalse(CategoryCatalog.defaultGastos.contains("Colegio"),
                       "si algún día se agrega al catálogo, este test pierde sentido, no el fix")
    }

    func testLaCategoriaPropiaDelHogarApareceEnElPicker() {
        let cats = disponibles(custom: blobConGasto("Colegio"), tipo: .gasto, actual: "Colegio")
        XCTAssertTrue(cats.contains("Colegio"))
    }

    /// El caso que corrompía: el blob no trae la categoría (se renombró, se
    /// borró, o todavía no cargó de red) pero el movimiento sí la tiene.
    func testLaCategoriaDelMovimientoApareceAunqueYaNoEsteEnElCatalogo() {
        let cats = disponibles(custom: nil, tipo: .gasto, actual: "Categoría borrada")
        XCTAssertEqual(cats.first, "Categoría borrada",
                       "sin esto el Picker queda sin selección y el primer toque la pisa")
    }

    /// Aunque falle la red y no haya blob, se tiene que poder editar igual.
    func testSinBlobSiguenEstandoLasPorDefecto() {
        let cats = disponibles(custom: nil, tipo: .gasto, actual: "Alimentación")
        XCTAssertTrue(cats.contains("Alimentación"))
        XCTAssertGreaterThan(cats.count, 1)
    }

    func testNoSeDuplicaCuandoLaCategoriaYaEstaba() {
        let cats = disponibles(custom: nil, tipo: .gasto, actual: "Alimentación")
        XCTAssertEqual(cats.filter { $0 == "Alimentación" }.count, 1)
    }

    func testLosIngresosUsanSuPropioCatalogo() {
        let cats = disponibles(custom: nil, tipo: .ingreso, actual: "Sueldo")
        XCTAssertTrue(cats.contains("Sueldo"))
        XCTAssertFalse(cats.contains("Alimentación"), "no mezclar gastos con ingresos")
    }
}
