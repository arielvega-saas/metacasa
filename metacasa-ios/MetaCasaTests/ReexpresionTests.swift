import XCTest
@testable import Home_Finance

/// Llevar plata de una fecha a otra.
///
/// Con 33,5% de inflación interanual, comparar "$80.000 en enero" contra
/// "$95.000 en junio" sin reexpresar es comparar dos monedas distintas con el
/// mismo nombre. Es el cálculo que hace que los números de la app signifiquen
/// algo en Argentina, así que se testea como se testea el dinero.
final class ReexpresionTests: XCTestCase {

    private let cal = Calendar.current

    private func fecha(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: iso)!
    }

    /// Valores REALES del CER del BCRA, para que el test valga como
    /// verificación y no sólo como aritmética inventada.
    private lazy var cer: [String: Decimal] = [
        "2025-08-08": Decimal(string: "613.87")!,
        "2026-08-01": Decimal(string: "815.92975500377")!,
        "2026-08-07": Decimal(string: "818.90754259824")!,
        "2026-08-08": Decimal(string: "819.40489603602")!,
    ]

    private func indice(_ d: Date) -> Decimal? { cer[CERService.clave(d)] }

    // MARK: - Lo esencial

    func testLlevarALaMismaFechaNoCambiaElMonto() {
        let hoy = fecha("2026-08-08")
        let r = Reexpresion.llevar(100_000, desde: hoy, hasta: hoy, indice: indice)
        XCTAssertEqual(r, 100_000)
    }

    /// Un año de inflación tiene que hacer crecer el monto reexpresado.
    func testUnMontoDeHaceUnAñoValeMasEnPesosDeHoy() throws {
        let r = try XCTUnwrap(Reexpresion.llevar(
            100_000, desde: fecha("2025-08-08"), hasta: fecha("2026-08-08"), indice: indice))
        // 100.000 × 819,40489603602 / 613,87 = 133.481,83
        XCTAssertEqual(r, Decimal(string: "133481.83")!)
        XCTAssertGreaterThan(r, 100_000)
    }

    /// Y al revés: traer plata de hoy al pasado la achica.
    func testTraerPlataDeHoyAlPasadoLaAchica() throws {
        let ida = try XCTUnwrap(Reexpresion.llevar(
            100_000, desde: fecha("2025-08-08"), hasta: fecha("2026-08-08"), indice: indice))
        let vuelta = try XCTUnwrap(Reexpresion.llevar(
            ida, desde: fecha("2026-08-08"), hasta: fecha("2025-08-08"), indice: indice))
        XCTAssertEqual(vuelta, Decimal(string: "100000.00")!, "el viaje de ida y vuelta cierra")
    }

    /// Sin dato para una de las fechas, se devuelve `nil`. Un número inventado
    /// en una app de plata es peor que no mostrar nada.
    func testSinIndiceDevuelveNilYNoInventa() {
        XCTAssertNil(Reexpresion.llevar(
            100_000, desde: fecha("2019-01-01"), hasta: fecha("2026-08-08"), indice: indice))
        XCTAssertNil(Reexpresion.llevar(
            100_000, desde: fecha("2026-08-08"), hasta: fecha("2030-01-01"), indice: indice))
    }

    func testMontoCeroSigueSiendoCero() {
        let r = Reexpresion.llevar(0, desde: fecha("2025-08-08"), hasta: fecha("2026-08-08"), indice: indice)
        XCTAssertEqual(r, 0)
    }

    /// Los ingresos también se reexpresan: el signo no cambia.
    func testUnMontoNegativoConservaElSigno() throws {
        let r = try XCTUnwrap(Reexpresion.llevar(
            -100_000, desde: fecha("2025-08-08"), hasta: fecha("2026-08-08"), indice: indice))
        XCTAssertLessThan(r, 0)
    }

    // MARK: - Poder de compra

    /// La frase que explica la inflación más rápido que cualquier gráfico.
    func testPoderDeCompraDeUnPesoDelAñoPasado() throws {
        let p = try XCTUnwrap(Reexpresion.poderDeCompra(
            de: fecha("2025-08-08"), a: fecha("2026-08-08"), indice: indice))
        // 613.87 / 819.40 ≈ 0,7492 → un peso de hace un año compra ~75 centavos
        XCTAssertEqual(p, Decimal(string: "0.7492")!)
    }

    func testElPoderDeCompraDeHoyEsUno() throws {
        let hoy = fecha("2026-08-08")
        XCTAssertEqual(try XCTUnwrap(Reexpresion.poderDeCompra(de: hoy, a: hoy, indice: indice)), 1)
    }

    // MARK: - Variación real

    /// El caso que le importa al usuario: un aumento nominal que en realidad
    /// fue una pérdida.
    func testUnAumentoMenorALaInflacionEsUnaPerdidaReal() throws {
        // Sueldo: 1.000.000 hace un año → 1.250.000 hoy (+25% nominal).
        let v = try XCTUnwrap(Reexpresion.variacionReal(
            anterior: 1_000_000, fechaAnterior: fecha("2025-08-08"),
            actual: 1_250_000, fechaActual: fecha("2026-08-08"),
            indice: indice))
        XCTAssertLessThan(v, 0, "subió 25% nominal con 33% de inflación: perdió")
        // 1.000.000 → 1.334.812 en pesos de hoy; (1.250.000 - 1.334.812)/1.334.812 ≈ -6,35%
        XCTAssertEqual(v, Decimal(string: "-0.0635")!)
    }

    func testUnAumentoMayorALaInflacionEsGananciaReal() throws {
        let v = try XCTUnwrap(Reexpresion.variacionReal(
            anterior: 1_000_000, fechaAnterior: fecha("2025-08-08"),
            actual: 1_500_000, fechaActual: fecha("2026-08-08"),
            indice: indice))
        XCTAssertGreaterThan(v, 0)
    }

    func testSinBaseNoHayVariacion() {
        XCTAssertNil(Reexpresion.variacionReal(
            anterior: 0, fechaAnterior: fecha("2025-08-08"),
            actual: 1_000_000, fechaActual: fecha("2026-08-08"),
            indice: indice))
    }

    // MARK: - El día calendario

    /// El índice es por DÍA. Si la clave se calculara en UTC, un gasto de las
    /// 22 h caería en el día siguiente y usaría otro valor del índice.
    func testLaClaveEsElDiaLocalDelUsuario() {
        let tarde = cal.date(bySettingHour: 22, minute: 30, second: 0, of: fecha("2026-08-07"))!
        XCTAssertEqual(CERService.clave(tarde), "2026-08-07")
        let temprano = cal.date(bySettingHour: 1, minute: 15, second: 0, of: fecha("2026-08-07"))!
        XCTAssertEqual(CERService.clave(temprano), "2026-08-07")
    }
}
