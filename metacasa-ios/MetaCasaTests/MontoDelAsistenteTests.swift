import XCTest
@testable import Home_Finance

/// El importe que manda el modelo llega como `Double` y termina en la columna
/// de plata.
///
/// Caso real: el asistente corrigió un gasto a 78.972,57 y en Postgres quedó
/// `78972.57000000001024`. `Decimal(unDouble)` conserva el error binario del
/// double. No cambia ningún total visible, pero es basura en dinero: reaparece
/// en exportaciones, en comparaciones por igualdad y en cualquier vista con más
/// de dos decimales.
final class MontoDelAsistenteTests: XCTestCase {

    /// Reproduce el caso exacto que se guardó mal.
    func testElCasoQueSeGuardoConBasura() {
        let sucio = Decimal(78972.57)
        XCTAssertNotEqual(sucio, Decimal(string: "78972.57")!,
                          "así entraba el error binario a la base")

        let limpio = redondear(78972.57)
        XCTAssertEqual(limpio, Decimal(string: "78972.57")!)
    }

    func testLosCentavosSobreviven() {
        XCTAssertEqual(redondear(1234.05), Decimal(string: "1234.05")!)
        XCTAssertEqual(redondear(0.01), Decimal(string: "0.01")!)
        XCTAssertEqual(redondear(19827.43), Decimal(string: "19827.43")!)
    }

    func testLosEnterosNoSeTocan() {
        XCTAssertEqual(redondear(98800), Decimal(98800))
        XCTAssertEqual(redondear(0), Decimal(0))
    }

    /// Un tercer decimal se redondea a centavos, no se trunca.
    func testElTercerDecimalRedondea() {
        XCTAssertEqual(redondear(10.005), Decimal(string: "10.01")!)
        XCTAssertEqual(redondear(10.004), Decimal(string: "10.00")!)
    }

    func testMontosGrandesLATAM() {
        XCTAssertEqual(redondear(2591362.43), Decimal(string: "2591362.43")!)
    }

    // Misma conversión que usa `AIToolHandler.montoDecimal` (privada por diseño:
    // el importe sólo debe convertirse en el borde donde entra).
    private func redondear(_ d: Double) -> Decimal {
        var origen = Decimal(d)
        var out = Decimal()
        NSDecimalRound(&out, &origen, 2, .plain)
        return out
    }
}
