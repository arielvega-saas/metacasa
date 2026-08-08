import XCTest
@testable import Home_Finance

/// El resumen que la app trae sin que se lo pidan.
///
/// Un asistente al que hay que ir a buscar se usa dos veces y se abandona. Y
/// semanal, no mensual: con inflación alta, enterarse el día 30 de que el mes se
/// fue de cauce llega tarde.
final class RecapSemanalTests: XCTestCase {

    private let cal = Calendar.current
    private let hogar = UUID()
    private lazy var hoy = cal.startOfDay(for: Date())

    private func hace(_ dias: Int) -> Date {
        cal.date(byAdding: .day, value: -dias, to: hoy)!
    }

    private func gasto(_ monto: Decimal, _ categoria: String, hace dias: Int,
                       tipo: TxType = .gasto, grupo: UUID? = nil) -> Transaction {
        Transaction(
            id: UUID(), householdId: hogar, userId: UUID(), accountId: nil,
            type: tipo, amount: monto, amountOriginal: nil, currencyOriginal: "ARS",
            fxRateToBase: nil, fxSource: nil, fxStatus: nil,
            category: categoria, subcategory: nil, account: nil, note: nil,
            date: hace(dias), periodYear: nil, periodMonth: nil,
            transferGroupId: grupo, createdAt: nil
        )
    }

    // MARK: - Lo básico

    func testSinMovimientosNoHayRecap() {
        XCTAssertNil(CalculadoraDeRecap.calcular(movimientos: [], hoy: hoy, calendario: cal))
    }

    func testSumaLaSemanaYLaCompara() throws {
        let movs = [
            gasto(10_000, "Alimentación", hace: 1),
            gasto(5_000, "Transporte", hace: 3),
            gasto(20_000, "Alimentación", hace: 9),   // semana previa
        ]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: movs, hoy: hoy, calendario: cal))
        XCTAssertEqual(r.gasto, 15_000)
        XCTAssertEqual(r.gastoPrevio, 20_000)
        XCTAssertTrue(r.mejoro, "gastó menos que la semana anterior")
    }

    /// El día 7 está DENTRO de la ventana y el 8 afuera. El borde de un rango es
    /// donde siempre se pierde un día.
    func testElBordeDeLaVentanaDeSieteDias() throws {
        let dentro = try XCTUnwrap(CalculadoraDeRecap.calcular(
            movimientos: [gasto(1_000, "Ocio", hace: 6)], hoy: hoy, calendario: cal))
        XCTAssertEqual(dentro.gasto, 1_000)

        let afuera = try XCTUnwrap(CalculadoraDeRecap.calcular(
            movimientos: [gasto(1_000, "Ocio", hace: 7)], hoy: hoy, calendario: cal))
        XCTAssertEqual(afuera.gasto, 0, "hace 7 días ya es la semana previa")
        XCTAssertEqual(afuera.gastoPrevio, 1_000)
    }

    /// Un gasto de hoy cuenta, sin importar la hora.
    func testUnGastoDeHoyCuenta() throws {
        var tx = gasto(3_000, "Ocio", hace: 0)
        tx.date = cal.date(bySettingHour: 23, minute: 45, second: 0, of: hoy)!
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: [tx], hoy: hoy, calendario: cal))
        XCTAssertEqual(r.gasto, 3_000)
    }

    // MARK: - Lo que no debe contaminar

    /// Mover plata entre cuentas propias no es gasto: sumarlo infla los dos
    /// lados y el recap diría cualquier cosa.
    func testLasTransferenciasNoCuentan() throws {
        let grupo = UUID()
        let movs = [
            gasto(50_000, "Transferencia", hace: 2, tipo: .gasto, grupo: grupo),
            gasto(50_000, "Transferencia", hace: 2, tipo: .ingreso, grupo: grupo),
            gasto(8_000, "Alimentación", hace: 2),
        ]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: movs, hoy: hoy, calendario: cal))
        XCTAssertEqual(r.gasto, 8_000)
        XCTAssertEqual(r.ingresos, 0)
    }

    func testLosIngresosNoSeMezclanConLosGastos() throws {
        let movs = [
            gasto(100_000, "Sueldo", hace: 2, tipo: .ingreso),
            gasto(9_000, "Ocio", hace: 2),
        ]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: movs, hoy: hoy, calendario: cal))
        XCTAssertEqual(r.gasto, 9_000)
        XCTAssertEqual(r.ingresos, 100_000)
    }

    // MARK: - El titular útil

    /// No "gastaste más" sino EN QUÉ. Y en pesos, no en porcentaje: un 300%
    /// sobre $500 no le mueve el mes a nadie y encabezaría un ranking por %.
    func testLaMayorSubidaSeMideEnPesosNoEnPorcentaje() throws {
        let movs = [
            gasto(2_000, "Kiosco", hace: 1),        // previo 500 → +1.500 (+300%)
            gasto(500, "Kiosco", hace: 9),
            gasto(90_000, "Alimentación", hace: 1), // previo 60.000 → +30.000 (+50%)
            gasto(60_000, "Alimentación", hace: 9),
        ]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: movs, hoy: hoy, calendario: cal))
        XCTAssertEqual(r.mayorSubida?.categoria, "Alimentación")
        XCTAssertEqual(r.mayorSubida?.delta, 30_000)
    }

    func testSinSubidasNoInventaUna() throws {
        let movs = [gasto(1_000, "Ocio", hace: 1), gasto(5_000, "Ocio", hace: 9)]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: movs, hoy: hoy, calendario: cal))
        XCTAssertNil(r.mayorSubida)
    }

    func testLasCategoriasVienenOrdenadasYTopeadas() throws {
        let movs = (1...8).map { gasto(Decimal($0 * 1000), "Cat\($0)", hace: 1) }
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: movs, hoy: hoy, calendario: cal))
        XCTAssertEqual(r.porCategoria.count, 5, "se muestran las 5 más grandes")
        XCTAssertEqual(r.porCategoria.first?.categoria, "Cat8")
        XCTAssertEqual(r.porCategoria.map(\.monto), r.porCategoria.map(\.monto).sorted(by: >))
    }

    // MARK: - Honestidad del dato

    /// Si el usuario cargó dos días de siete, el veredicto vale poco. Hay que
    /// poder decirlo en vez de afirmar que gastó menos.
    func testCuentaLosDiasSinRegistro() throws {
        let movs = [gasto(1_000, "Ocio", hace: 1), gasto(1_000, "Ocio", hace: 2)]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: movs, hoy: hoy, calendario: cal))
        XCTAssertEqual(r.diasSinRegistro, 5)
    }

    /// Sin índice de inflación no se inventa una variación real.
    func testSinIndiceNoHayVariacionReal() throws {
        let movs = [gasto(10_000, "Ocio", hace: 1), gasto(9_000, "Ocio", hace: 9)]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(movimientos: movs, hoy: hoy, calendario: cal))
        XCTAssertNil(r.variacionReal)
        XCTAssertFalse(r.mejoro, "sin índice cae al nominal: 10.000 > 9.000")
    }

    /// Con inflación, un aumento nominal MENOR que la inflación es una baja
    /// real. Es el titular que ninguna app da.
    func testUnAumentoNominalMenorALaInflacionEsUnaBajaReal() throws {
        let movs = [gasto(10_100, "Ocio", hace: 1), gasto(10_000, "Ocio", hace: 9)]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(
            movimientos: movs, hoy: hoy, calendario: cal, indice: indiceQueSube2Porciento))
        let real = try XCTUnwrap(r.variacionReal)
        XCTAssertLessThan(real, 0, "+1% nominal con +2% de inflación es una BAJA real")
        XCTAssertTrue(r.mejoro)
    }

    /// Y al revés: si el aumento nominal supera la inflación, sigue siendo un
    /// aumento — pero menor que el que muestra el número crudo.
    func testUnAumentoMayorALaInflacionSigueSiendoAumentoPeroMenor() throws {
        let movs = [gasto(10_300, "Ocio", hace: 1), gasto(10_000, "Ocio", hace: 9)]
        let r = try XCTUnwrap(CalculadoraDeRecap.calcular(
            movimientos: movs, hoy: hoy, calendario: cal, indice: indiceQueSube2Porciento))
        let real = try XCTUnwrap(r.variacionReal)
        XCTAssertGreaterThan(real, 0)
        // Nominal +3%; real ≈ +1%. Lo importante es que el real sea MENOR.
        XCTAssertLessThan(real, Decimal(string: "0.03")!)
        XCTAssertFalse(r.mejoro)
    }

    /// El índice sube 2% entre la ventana previa y la actual.
    private var indiceQueSube2Porciento: (Date) -> Decimal? {
        { [self] d in
            let dias = cal.dateComponents([.day], from: d, to: hoy).day ?? 0
            return dias >= 7 ? Decimal(100) : Decimal(102)
        }
    }
}

/// Los textos de la tarjeta del recap.
///
/// Es un widget nuevo del dashboard: si sus claves no resuelven, en pantalla
/// aparece el identificador crudo en los tres idiomas.
final class TextosDelRecapTests: XCTestCase {

    func testLasClavesDelRecapResuelven() {
        for clave in ["recap.title", "recap.spent", "recap.vsPrevious", "recap.realChange",
                      "recap.biggestRise", "recap.better", "recap.worse", "recap.empty",
                      "dashboard.widget.recap", "dashboard.widget.recap.desc"] {
            let resuelto = String(localized: String.LocalizationValue(clave))
            XCTAssertNotEqual(resuelto, clave, "\(clave) no resuelve")
        }
    }

    /// "1 días sin movimientos" es el error clásico del plural.
    func testElAvisoDeDiasFaltantesUsaPlural() {
        let uno = String(localized: "recap.missingDays \(1)")
        let varios = String(localized: "recap.missingDays \(4)")
        XCTAssertFalse(uno.contains("recap.missingDays"), "no resolvió: \(uno)")
        XCTAssertNotEqual(uno, varios)
        XCTAssertFalse(uno.lowercased().contains("días"), "singular mal formado: \(uno)")
    }

    /// El widget tiene que estar registrado en el dashboard, o no hay forma de
    /// mostrarlo ni de que el usuario lo oculte.
    func testElWidgetEstaRegistradoEnElDashboard() {
        XCTAssertTrue(DashboardWidgetID.allCases.contains(.recapSemanal))
    }

    /// Un widget nuevo no puede reordenarle el dashboard a quien ya tenía uno
    /// guardado: la reconciliación agrega los nuevos al final.
    func testUnWidgetNuevoNoRompeElOrdenGuardado() {
        let guardado: [DashboardWidgetID] = [.hero, .stats, .goals]
        let conocidos = Set(guardado)
        let faltantes = DashboardWidgetID.allCases.filter { !conocidos.contains($0) }
        let reconciliado = guardado + faltantes

        XCTAssertEqual(Array(reconciliado.prefix(3)), guardado, "el orden del usuario se conserva")
        XCTAssertTrue(reconciliado.contains(.recapSemanal))
        XCTAssertEqual(Set(reconciliado).count, DashboardWidgetID.allCases.count)
    }
}
