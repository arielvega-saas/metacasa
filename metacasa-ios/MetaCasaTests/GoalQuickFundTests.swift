import XCTest
@testable import Home_Finance

/// Tests de los montos sugeridos para fondear metas.
///
/// Es lógica de dinero que va detrás de un botón de un solo toque: si sugiere un monto mayor al que
/// falta, el usuario se pasa de su propia meta sin querer. Por eso las aserciones se concentran en los
/// límites, no en el caso lindo.
final class GoalQuickFundTests: XCTestCase {

    private func amounts(current: Decimal, target: Decimal) -> [Decimal] {
        GoalQuickFund.suggestions(current: current, target: target).map(\.amount)
    }

    // MARK: - Redondeo

    func testRedondeaADosCifrasSignificativas() {
        XCTAssertEqual(GoalQuickFund.roundedDown(1234), 1200)
        XCTAssertEqual(GoalQuickFund.roundedDown(98765), 98000)
        XCTAssertEqual(GoalQuickFund.roundedDown(450), 450)
        XCTAssertEqual(GoalQuickFund.roundedDown(457), 450)
    }

    func testNumerosChicosPasanTruncadosAEntero() {
        XCTAssertEqual(GoalQuickFund.roundedDown(45), 45)
        XCTAssertEqual(GoalQuickFund.roundedDown(7), 7)
        XCTAssertEqual(GoalQuickFund.roundedDown(Decimal(string: "7.9")!), 7)
    }

    func testRedondeaSiempreHaciaAbajo() {
        // Hacia arriba, un cuarto de lo que falta podría terminar superando lo que falta.
        XCTAssertEqual(GoalQuickFund.roundedDown(Decimal(string: "1299.99")!), 1200)
        XCTAssertEqual(GoalQuickFund.roundedDown(Decimal(string: "0.9")!), 0)
    }

    // MARK: - Sugerencias

    func testSugiereUnCuartoLaMitadYCompletar() {
        // Faltan 1000 → 250, 500 y completar con 1000.
        XCTAssertEqual(amounts(current: 0, target: 1000), [250, 500, 1000])
    }

    func testLaUltimaSugerenciaSiempreCompletaLaMeta() {
        let s = GoalQuickFund.suggestions(current: 700, target: 1000)
        XCTAssertEqual(s.last?.amount, 300, "debe completar exactamente lo que falta")
        XCTAssertEqual(s.last?.completesGoal, true)
        XCTAssertEqual(s.filter(\.completesGoal).count, 1, "sólo una debe marcarse como completar")
    }

    /// La invariante que más importa: ninguna sugerencia puede pasarse de lo que falta.
    func testNingunaSugerenciaSuperaLoQueFalta() {
        let casos: [(Decimal, Decimal)] = [
            (0, 3), (0, 7), (0, 100), (0, 1000), (0, 999_999),
            (33, 100), (999, 1000), (1, 3), (12_345, 98_765)
        ]
        for (current, target) in casos {
            let falta = target - current
            for a in amounts(current: current, target: target) {
                XCTAssertLessThanOrEqual(a, falta, "sugirió \(a) con \(falta) faltante (meta \(current)/\(target))")
                XCTAssertGreaterThan(a, 0, "sugirió un monto no positivo con \(falta) faltante")
            }
        }
    }

    func testSugerenciasOrdenadasDeMenorAMayor() {
        let a = amounts(current: 0, target: 98_765)
        XCTAssertEqual(a, a.sorted(), "las sugerencias deben ir de menor a mayor")
    }

    // MARK: - Cuándo NO sugerir

    func testMetaCumplidaNoSugiereNada() {
        XCTAssertTrue(amounts(current: 1000, target: 1000).isEmpty)
    }

    func testMetaPasadaDeObjetivoNoSugiereNada() {
        XCTAssertTrue(amounts(current: 1500, target: 1000).isEmpty)
    }

    func testObjetivoEnCeroNoSugiereNada() {
        XCTAssertTrue(amounts(current: 0, target: 0).isEmpty)
    }

    /// Con montos muy chicos, un cuarto y la mitad colapsan al mismo número o a cero.
    /// No debe haber duplicados ni un chip de "0".
    func testMontosChicosNoGeneranDuplicadosNiCeros() {
        let s = amounts(current: 0, target: 3)
        XCTAssertEqual(Set(s).count, s.count, "no debe repetir montos")
        XCTAssertFalse(s.contains(0))
        XCTAssertEqual(s.last, 3)

        let unPeso = amounts(current: 0, target: 1)
        XCTAssertEqual(unPeso, [1], "con 1 de faltante, la única acción posible es completar")
    }
}
