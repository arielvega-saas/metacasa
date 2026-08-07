import XCTest
@testable import Home_Finance

/// Tipear un monto con separador de miles.
///
/// `Money.parse` toma el separador **más a la derecha** como decimal, sin mirar
/// cuántos dígitos lo siguen. Con eso, "15.000" —la forma normal de escribir
/// quince mil en Argentina— se leía como quince pesos. En una app de finanzas
/// eso no es un error de formato: es el monto equivocado guardado en la base,
/// sin ningún aviso.
///
/// Ninguna moneda soportada (ARS, USD, EUR, BRL) tiene 3 decimales, así que
/// tres dígitos detrás del separador sólo pueden ser un grupo de miles.
final class MoneyParseTests: XCTestCase {

    private func parse(_ s: String) -> Decimal? { Money.parse(s) }

    /// Un literal `Decimal` en Swift se construye pasando por `Double`, así que
    /// `1234.56` no es exactamente el `Decimal` que sale de parsear "1234.56".
    /// Los esperados se arman desde string para comparar el mismo valor.
    private func dec(_ s: String) -> Decimal { Decimal(string: s)! }

    func testUnSeparadorConTresDigitosEsMiles() {
        XCTAssertEqual(parse("15.000"), 15000)
        XCTAssertEqual(parse("15,000"), 15000)
        XCTAssertEqual(parse("1.500"), 1500)
        XCTAssertEqual(parse("1,500"), 1500)
    }

    func testUnSeparadorConUnoODosDigitosSigueSiendoDecimal() {
        XCTAssertEqual(parse("1,50"), dec("1.5"))
        XCTAssertEqual(parse("1.50"), dec("1.5"))
        XCTAssertEqual(parse("1,5"), dec("1.5"))
        XCTAssertEqual(parse("0.75"), dec("0.75"))
    }

    func testLosCasosNoAmbiguosSiguenIgual() {
        XCTAssertEqual(parse("1.234,56"), dec("1234.56"))   // LatAm
        XCTAssertEqual(parse("1,234.56"), dec("1234.56"))   // US
        XCTAssertEqual(parse("1.234.567"), 1234567)
        XCTAssertEqual(parse("1,234,567"), 1234567)
        XCTAssertEqual(parse("15.000,50"), dec("15000.5"))
        XCTAssertEqual(parse("1500"), 1500)
    }

    func testCuatroDigitosDetrasSiguenSiendoDecimales() {
        XCTAssertEqual(parse("12.3456"), dec("12.3456"))
    }

    /// Si la app no puede releer lo que ella misma escribió, cualquier campo
    /// prellenado con un monto formateado se corrompe al guardar.
    /// Sólo montos enteros: `Money.format` muestra ARS sin centavos (correcto,
    /// el peso no los usa), así que un valor con decimales se redondea al
    /// formatear y el round-trip exacto no aplica — eso es el formateador
    /// haciendo su trabajo, no el parser perdiendo plata.
    func testIdaYVueltaConElPropioFormato() {
        for texto in ["1500", "15000", "250000", "1234567"] {
            let monto = dec(texto)
            let formateado = Money.format(monto, currency: "ARS")
            XCTAssertEqual(parse(formateado), monto,
                           "no sobrevivió el round-trip: \(formateado)")
        }
    }

    /// Los símbolos compuestos del dólar y el real tienen que salir enteros.
    ///
    /// Se quitaba el `"$"` suelto **antes** que `"U$S"`/`"US$"`/`"R$"`, así que
    /// quedaba la letra pegada al número ("U$S 5.000" → "US 5.000") y `parse`
    /// devolvía `nil`: un monto tipeado con el símbolo completo era ilegible.
    func testSimbolosCompuestosNoDejanLetrasPegadas() {
        XCTAssertEqual(parse("U$S 5.000"), 5000)
        XCTAssertEqual(parse("US$ 1.234.568"), 1234568)
        XCTAssertEqual(parse("R$ 2.500,10"), dec("2500.10"))
    }

    func testSimbolosYEspaciosSiguenIgnorandose() {
        XCTAssertEqual(parse("$ 15.000"), 15000)
        XCTAssertEqual(parse("ARS 1.234,56"), dec("1234.56"))
    }
}
