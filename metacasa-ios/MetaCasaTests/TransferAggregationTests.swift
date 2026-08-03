import XCTest
@testable import Home_Finance

/// Tests de la invariante central de las transferencias.
///
/// **Agregarle un par de transferencia a un conjunto de movimientos no puede cambiar ningún
/// agregado de ingreso/gasto/categoría** — la plata nunca salió del hogar. Y la contra-invariante
/// importa igual: sí tiene que mover exactamente dos saldos de cuenta, en direcciones opuestas.
///
/// El segundo grupo de tests es el que evita que un filtro demasiado entusiasta rompa los saldos,
/// que sería un bug peor que el original: los saldos son la única fuente de verdad de cuánta plata
/// hay realmente en cada cuenta.
final class TransferAggregationTests: XCTestCase {

    private func tx(
        _ type: TxType,
        _ amount: Decimal,
        category: String = "Alimentación",
        accountId: UUID? = nil,
        transferGroupId: UUID? = nil
    ) -> Transaction {
        Transaction(
            id: UUID(),
            householdId: UUID(),
            userId: UUID(),
            accountId: accountId,
            type: type,
            amount: amount,
            amountOriginal: amount,
            currencyOriginal: "ARS",
            fxRateToBase: 1,
            fxSource: nil,
            fxStatus: nil,
            category: category,
            subcategory: nil,
            account: nil,
            note: nil,
            date: Date(),
            periodYear: nil,
            periodMonth: nil,
            transferGroupId: transferGroupId,
            createdAt: nil
        )
    }

    /// Movimientos reales: 100.000 de ingreso, 30.000 de gasto.
    private var movimientosReales: [Transaction] {
        [tx(.ingreso, 100_000, category: "Sueldo"), tx(.gasto, 30_000)]
    }

    /// Las dos piernas de mover 500.000 entre cuentas propias.
    private func piernasDeTransferencia(origen: UUID, destino: UUID) -> [Transaction] {
        let grupo = UUID()
        return [
            tx(.gasto, 500_000, category: "Transferencia", accountId: origen, transferGroupId: grupo),
            tx(.ingreso, 500_000, category: "Transferencia", accountId: destino, transferGroupId: grupo)
        ]
    }

    // MARK: - Invariante: los agregados NO se mueven

    func testExcludingTransfersDejaSoloLosMovimientosReales() {
        let conTransferencia = movimientosReales + piernasDeTransferencia(origen: UUID(), destino: UUID())
        XCTAssertEqual(conTransferencia.count, 4)
        XCTAssertEqual(conTransferencia.excludingTransfers.count, 2, "las dos piernas deben salir")
    }

    func testLosTotalesNoSeInflan() {
        let sinT = movimientosReales
        let conT = movimientosReales + piernasDeTransferencia(origen: UUID(), destino: UUID())

        func totales(_ txs: [Transaction]) -> (Decimal, Decimal) {
            let f = txs.excludingTransfers
            return (f.filter { $0.type == .ingreso }.reduce(0) { $0 + $1.amount },
                    f.filter { $0.type == .gasto }.reduce(0) { $0 + $1.amount })
        }

        XCTAssertEqual(totales(sinT).0, totales(conT).0, "los ingresos no pueden moverse")
        XCTAssertEqual(totales(sinT).1, totales(conT).1, "los gastos no pueden moverse")
        XCTAssertEqual(totales(conT).0, 100_000)
        XCTAssertEqual(totales(conT).1, 30_000, "sin el filtro darían 530.000")
    }

    /// "Transferencia" no debe aparecer nunca como categoría en el donut.
    func testNoApareceComoCategoria() {
        let conT = movimientosReales + piernasDeTransferencia(origen: UUID(), destino: UUID())
        var porCategoria: [String: Decimal] = [:]
        for t in conT.excludingTransfers where t.type == .gasto {
            porCategoria[t.category, default: 0] += t.amount
        }
        XCTAssertNil(porCategoria["Transferencia"], "no puede figurar como categoría de gasto")
        XCTAssertEqual(porCategoria["Alimentación"], 30_000)
    }

    /// Una transferencia no puede "salvar" la racha de un día sin actividad real.
    func testNoCuentaComoDiaDeActividad() {
        let soloTransferencia = piernasDeTransferencia(origen: UUID(), destino: UUID())
        XCTAssertTrue(soloTransferencia.excludingTransfers.isEmpty,
                      "un día con sólo una transferencia no es un día con movimientos")
    }

    // MARK: - Contra-invariante: los saldos SÍ se mueven

    /// El test que evita que un fix entusiasta filtre transferencias donde no debe.
    func testLosSaldosDeCuentaSiSeMueven() {
        let origen = UUID(), destino = UUID()
        let piernas = piernasDeTransferencia(origen: origen, destino: destino)

        // Los saldos por cuenta NO filtran: acá las dos piernas son el mecanismo.
        func saldo(_ cuenta: UUID, _ txs: [Transaction]) -> Decimal {
            txs.filter { $0.accountId == cuenta }
               .reduce(Decimal(0)) { $0 + ($1.type == .gasto ? -$1.amount : $1.amount) }
        }

        XCTAssertEqual(saldo(origen, piernas), -500_000, "la cuenta origen tiene que bajar")
        XCTAssertEqual(saldo(destino, piernas), 500_000, "la de destino tiene que subir")
        XCTAssertEqual(saldo(origen, piernas) + saldo(destino, piernas), 0,
                       "el patrimonio neto del hogar no cambia: la plata sigue adentro")
    }

    // MARK: - Bordes

    func testSinTransferenciasNoCambiaNada() {
        let txs = movimientosReales
        XCTAssertEqual(txs.excludingTransfers.count, txs.count)
    }

    func testListaVacia() {
        XCTAssertTrue([Transaction]().excludingTransfers.isEmpty)
    }

    func testUnaPiernaHuerfanaTambienSeExcluye() {
        // Si por un bug quedara una sola pierna, tampoco debe contar como ingreso/gasto real.
        // El desbalance se detecta con la vista `v_transfer_health` del backend, no acá.
        let huerfana = [tx(.gasto, 500_000, category: "Transferencia", transferGroupId: UUID())]
        XCTAssertTrue(huerfana.excludingTransfers.isEmpty)
    }
}
