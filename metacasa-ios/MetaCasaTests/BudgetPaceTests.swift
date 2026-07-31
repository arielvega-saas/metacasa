import XCTest
@testable import Home_Finance

/// Tests de la proyección de ritmo de gasto.
///
/// Es lógica de dinero que se le muestra al usuario como advertencia ("a este ritmo llegás al 110%"),
/// así que vale la misma regla que `Money`: nada de tocarla sin tests. El riesgo específico acá no es
/// que dé un número mal, sino que **alarme cuando no corresponde** (proyectar el día 1) o que **calle
/// cuando corresponde** (no avisar el día 10 de un mes que va a terminar 40% pasado).
final class BudgetPaceTests: XCTestCase {

    /// Calendario fijo en UTC: sin esto, correr los tests en otro huso puede correr los días
    /// y hacer fallar aserciones de "día 10 del mes".
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Enero 2026: 1-ene a 31-ene. `periodEnd` es el ÚLTIMO día, como lo genera
    /// `BudgetService.ensurePeriodForMonth`.
    private let year = 2026
    private var enero: (start: Date, end: Date) { (date(year, 1, 1), date(year, 1, 31)) }

    private func pace(spent: Decimal, allocated: Decimal, on day: Int) -> BudgetPace? {
        BudgetPace.compute(
            spent: spent,
            allocated: allocated,
            periodStart: enero.start,
            periodEnd: enero.end,
            now: date(year, 1, day),
            calendar: calendar
        )
    }

    // MARK: - Cálculo

    func testProyectaAlRitmoAMitadDeMes() {
        // Día 15 de 31 → 15/31 transcurrido. Gastó 500 → proyecta 500 * 31/15 ≈ 1033,33.
        guard let p = pace(spent: 500, allocated: 1000, on: 15) else {
            return XCTFail("esperaba proyección a mitad de mes")
        }
        XCTAssertEqual(p.fractionElapsed, 15.0 / 31.0, accuracy: 0.0001)
        XCTAssertEqual((p.projectedSpend as NSDecimalNumber).doubleValue, 1033.333, accuracy: 0.01)
        XCTAssertEqual(p.projectedPercent, 1.0333, accuracy: 0.001)
        XCTAssertTrue(p.willOverspend)
    }

    func testElDiaEnCursoCuentaComoTranscurrido() {
        // El día 1 es 1/31 de mes transcurrido, no 0/31 — con 0 la división explotaría.
        // Como 1/31 < 0.15, acá se verifica vía el día 5 (5/31 ≈ 0,161).
        let p = pace(spent: 100, allocated: 1000, on: 5)
        XCTAssertNotNil(p)
        XCTAssertEqual(p!.fractionElapsed, 5.0 / 31.0, accuracy: 0.0001)
    }

    func testRitmoQueNoSePasaNoMarcaOverspend() {
        // Día 20, gastó 500 de 1000 → proyecta 775. Va bien.
        let p = pace(spent: 500, allocated: 1000, on: 20)
        XCTAssertNotNil(p)
        XCTAssertFalse(p!.willOverspend)
        XCTAssertEqual(p!.projectedPercent, 0.775, accuracy: 0.001)
    }

    func testUltimoDiaDelPeriodoProyectaLoYaGastado() {
        // Día 31 de 31: la proyección converge al gasto real, sin inflarlo.
        let p = pace(spent: 900, allocated: 1000, on: 31)
        XCTAssertNotNil(p)
        XCTAssertEqual((p!.projectedSpend as NSDecimalNumber).doubleValue, 900, accuracy: 0.001)
        XCTAssertEqual(p!.fractionElapsed, 1.0, accuracy: 0.0001)
    }

    // MARK: - Cuándo NO proyectar (lo que más importa)

    func testNoProyectaAntesDelPisoDeDiasTranscurridos() {
        // Día 2: una sola compra proyectaría 15× el gasto. Es ruido, no señal.
        XCTAssertNil(pace(spent: 400, allocated: 1000, on: 2))
        // Día 4 sigue por debajo del piso (4/31 ≈ 0,129).
        XCTAssertNil(pace(spent: 400, allocated: 1000, on: 4))
    }

    func testNoProyectaSinPresupuestoAsignado() {
        XCTAssertNil(pace(spent: 500, allocated: 0, on: 15))
    }

    func testNoProyectaSinGasto() {
        XCTAssertNil(pace(spent: 0, allocated: 1000, on: 15))
    }

    func testNoProyectaSobreUnPeriodoTerminado() {
        // Febrero mirando enero: el gasto de enero ya es un hecho. Decir "proyectado" sería falso.
        let p = BudgetPace.compute(
            spent: 500, allocated: 1000,
            periodStart: enero.start, periodEnd: enero.end,
            now: date(year, 2, 3), calendar: calendar
        )
        XCTAssertNil(p)
    }

    func testNoProyectaSobreUnPeriodoFuturo() {
        let febrero = (start: date(year, 2, 1), end: date(year, 2, 28))
        let p = BudgetPace.compute(
            spent: 500, allocated: 1000,
            periodStart: febrero.start, periodEnd: febrero.end,
            now: date(year, 1, 20), calendar: calendar
        )
        XCTAssertNil(p)
    }

    func testFuncionaConMesesDeDistintaLongitud() {
        // Febrero 2026 (28 días): día 14 es la mitad exacta → proyecta el doble.
        let p = BudgetPace.compute(
            spent: 300, allocated: 1000,
            periodStart: date(year, 2, 1), periodEnd: date(year, 2, 28),
            now: date(year, 2, 14), calendar: calendar
        )
        XCTAssertNotNil(p)
        XCTAssertEqual((p!.projectedSpend as NSDecimalNumber).doubleValue, 600, accuracy: 0.001)
    }

    // MARK: - Semáforo

    func testSemaforoUsaLosMismosCortesQueLaBarra() {
        func status(spent: Decimal) -> EnvelopeStatus {
            EnvelopeStatus(category: "Test", subcategory: "", allocated: 1000, spent: spent)
        }
        XCTAssertEqual(status(spent: 500).severity, .ok)
        XCTAssertEqual(status(spent: 800).severity, .ok)        // 0,80 exacto todavía es ok
        XCTAssertEqual(status(spent: 850).severity, .warning)
        XCTAssertEqual(status(spent: 960).severity, .critical)
        XCTAssertEqual(status(spent: 1200).severity, .critical) // pasado de presupuesto
    }

    /// Un envelope pasado de presupuesto es crítico aunque `percentUsed` esté topeado en 1.
    func testPasadoDePresupuestoEsCriticoAunqueElPorcentajeEsteTopeado() {
        let s = EnvelopeStatus(category: "Test", subcategory: "", allocated: 1000, spent: 3000)
        XCTAssertEqual(s.percentUsed, 1.0, accuracy: 0.0001)
        XCTAssertTrue(s.isOverBudget)
        XCTAssertEqual(s.severity, .critical)
    }
}
