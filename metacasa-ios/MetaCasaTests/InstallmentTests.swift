import XCTest
@testable import Home_Finance

/// Tests del reparto de cuotas.
///
/// La invariante que importa: **la suma de las cuotas tiene que dar el total exacto**. Un usuario
/// que suma sus doce cuotas y no llega al total de su plan deja de confiar en los números de la app,
/// y con razón.
final class InstallmentTests: XCTestCase {

    private func plan(total: Decimal, cuotas: Int) -> InstallmentPlan {
        InstallmentPlan(
            id: UUID(),
            householdId: UUID(),
            name: "Test",
            totalAmount: total,
            totalInstallments: cuotas,
            currency: "ARS",
            startYear: 2026,
            startMonth: 1,
            category: "Otros",
            accountId: nil,
            note: nil,
            status: .active,
            createdBy: UUID(),
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func suma(_ p: InstallmentPlan) -> Decimal {
        (1...p.totalInstallments).reduce(Decimal(0)) { $0 + p.amount(forInstallment: $1) }
    }

    /// El caso que motivó el fix: 1.000.000 / 12 no es exacto.
    func testElResiduoSeAbsorbeEnLaUltimaCuota() {
        let p = plan(total: 1_000_000, cuotas: 12)
        XCTAssertEqual(p.monthlyAmount, Decimal(string: "83333.33"))
        XCTAssertEqual(p.amount(forInstallment: 1), Decimal(string: "83333.33"))
        XCTAssertEqual(p.amount(forInstallment: 11), Decimal(string: "83333.33"))
        // 1.000.000 − 11 × 83.333,33 = 83.333,37
        XCTAssertEqual(p.amount(forInstallment: 12), Decimal(string: "83333.37"))
        XCTAssertEqual(suma(p), 1_000_000, "la suma de las cuotas debe dar el total EXACTO")
    }

    /// La invariante, barrida sobre casos feos.
    func testLaSumaSiempreDaElTotalExacto() {
        let casos: [(Decimal, Int)] = [
            (1_000_000, 12), (100, 3), (10, 3), (0.01, 3), (999.99, 7),
            (1, 12), (123_456.78, 5), (50_000, 6), (7, 2), (33.33, 9)
        ]
        for (total, cuotas) in casos {
            let p = plan(total: total, cuotas: cuotas)
            XCTAssertEqual(suma(p), total, "total \(total) en \(cuotas) cuotas no cierra")
        }
    }

    func testDivisionExactaDejaTodasLasCuotasIguales() {
        let p = plan(total: 1200, cuotas: 12)
        for n in 1...12 {
            XCTAssertEqual(p.amount(forInstallment: n), 100, "la cuota \(n) debería ser 100")
        }
    }

    func testUnaSolaCuotaEsElTotal() {
        let p = plan(total: 777.77, cuotas: 1)
        XCTAssertEqual(p.amount(forInstallment: 1), Decimal(string: "777.77"))
    }

    // MARK: - Bordes

    func testCuotasFueraDeRangoDanCero() {
        let p = plan(total: 1000, cuotas: 10)
        XCTAssertEqual(p.amount(forInstallment: 0), 0)
        XCTAssertEqual(p.amount(forInstallment: 11), 0)
        XCTAssertEqual(p.amount(forInstallment: -1), 0)
    }

    func testCeroCuotasNoDivideporCero() {
        let p = plan(total: 1000, cuotas: 0)
        XCTAssertEqual(p.monthlyAmount, 0)
        XCTAssertEqual(p.amount(forInstallment: 1), 0)
    }

    /// Un total tan chico que no alcanza para repartir: todo cae en la última.
    func testTotalMenorQueLaCantidadDeCuotas() {
        let p = plan(total: Decimal(string: "0.02")!, cuotas: 5)
        XCTAssertEqual(suma(p), Decimal(string: "0.02"), "aun así la suma debe cerrar")
    }
}
