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

    func testElDiaEnCursoCuentaComoTranscurrido() throws {
        // El día 1 es 1/31 de mes transcurrido, no 0/31 — con 0 la división explotaría.
        //
        // Se verifica en el día 8 y no en el 5: el piso subió a 0,25 el 2026-08-04 porque con 0,15
        // el alquiler pagado el día 1 seguía proyectando 575%. 8/31 ≈ 0,258 es el primer día que
        // proyecta. Si el piso vuelve a moverse, este test falla y hay que elegir otro día a
        // propósito — que es lo correcto: la fracción exacta es parte del contrato.
        let p = try XCTUnwrap(pace(spent: 100, allocated: 1000, on: 8))
        XCTAssertEqual(p.fractionElapsed, 8.0 / 31.0, accuracy: 0.0001)
    }

    /// El piso, explícito: un día antes no proyecta, el día del piso sí.
    func testElPisoEsExactamenteElDia8() {
        XCTAssertNil(pace(spent: 100, allocated: 1000, on: 7), "7/31 ≈ 0,226 < 0,25")
        XCTAssertNotNil(pace(spent: 100, allocated: 1000, on: 8), "8/31 ≈ 0,258 ≥ 0,25")
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

    // MARK: - El gasto fijo de principio de mes (bug encontrado en pantalla, 2026-08-04)

    /// El caso real: alquiler de 520.000 sobre un sobre de 560.000, pagado el día 1.
    /// Con el piso viejo de 0,15 (día 5) esto mostraba **"a este ritmo llegás al 575%"**.
    ///
    /// La proyección lineal asume que el gasto se reparte parejo en el mes, y los gastos fijos de
    /// principio de mes rompen ese supuesto: un pago único proyectado como ritmo da un número
    /// absurdo. El número era matemáticamente correcto y completamente inútil.
    func testElAlquilerDelDia1NoProyectaEnLaPrimeraSemana() {
        let pace = BudgetPace.compute(
            spent: 520_000, allocated: 560_000,
            periodStart: date(2026, 8, 1), periodEnd: date(2026, 8, 31),
            now: date(2026, 8, 5), calendar: calendar
        )
        XCTAssertNil(pace, "el día 5 el ritmo todavía es un gasto fijo disfrazado de tendencia")
    }

    /// Pasado el piso nuevo sí proyecta — pero el número gigante no se muestra como número.
    func testUnaProyeccionAbsurdaNoSeMuestraComoNumero() throws {
        let pace = try XCTUnwrap(BudgetPace.compute(
            spent: 520_000, allocated: 560_000,
            periodStart: date(2026, 8, 1), periodEnd: date(2026, 8, 31),
            now: date(2026, 8, 10), calendar: calendar
        ))
        XCTAssertTrue(pace.willOverspend, "pasarse es cierto y hay que avisarlo")
        XCTAssertFalse(pace.hasMeaningfulPercent,
                       "un 288% se lee como error de la app; el aviso va en cualitativo")
    }

    /// Y una proyección razonable SÍ conserva el número, que es más accionable.
    func testUnaProyeccionRazonableConservaElNumero() throws {
        let pace = try XCTUnwrap(BudgetPace.compute(
            spent: 60_000, allocated: 100_000,
            periodStart: date(2026, 8, 1), periodEnd: date(2026, 8, 31),
            now: date(2026, 8, 16), calendar: calendar
        ))
        XCTAssertTrue(pace.willOverspend)
        XCTAssertTrue(pace.hasMeaningfulPercent)
        XCTAssertEqual(pace.projectedPercent, 1.16, accuracy: 0.02, "116%: informativo y creíble")
    }

    /// El piso nuevo deja activa la mayor parte del mes, que es cuando sirve.
    func testElPisoNuevoNoApagaLaFeature() {
        for dia in 8...31 {
            let pace = BudgetPace.compute(
                spent: 60_000, allocated: 100_000,
                periodStart: date(2026, 8, 1), periodEnd: date(2026, 8, 31),
                now: date(2026, 8, dia), calendar: calendar
            )
            XCTAssertNotNil(pace, "el día \(dia) debería proyectar")
        }
    }

}
