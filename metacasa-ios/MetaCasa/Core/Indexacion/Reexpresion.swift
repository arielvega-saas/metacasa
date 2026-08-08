import Foundation

/// Llevar plata de una fecha a otra.
///
/// ─── POR QUÉ ES EL DIFERENCIAL DE ESTA APP ────────────────────────────────
/// Con 33,5% de inflación interanual, comparar "gasté $80.000 en enero" contra
/// "$95.000 en junio" sin reexpresar es comparar dos monedas distintas con el
/// mismo nombre. Todo gráfico de serie larga en Argentina miente, y el usuario
/// lo sabe: es la razón por la que las apps globales se sienten de juguete acá.
///
/// Ninguna app mainstream reexpresa el histórico —se buscó explícitamente y el
/// hallazgo negativo fue sólido—. No es una feature más: es la que hace que los
/// números de la app signifiquen algo.
///
/// **Regla de oro**: se guarda SIEMPRE el importe nominal y la fecha. La
/// reexpresión se calcula al vuelo. Guardar el valor ajustado lo pudre: mañana
/// el índice cambia y el número guardado queda mintiendo para siempre.
enum Reexpresion {

    /// Lleva `monto`, que es de `desde`, a la moneda de `hasta`.
    ///
    /// `indice` devuelve el valor del índice para un día; devolver `nil` para
    /// una fecha sin dato es válido y hace que la función devuelva `nil` en vez
    /// de inventar. **Un número inventado en una app de plata es peor que no
    /// mostrar nada.**
    static func llevar(
        _ monto: Decimal,
        desde: Date,
        hasta: Date,
        indice: (Date) -> Decimal?
    ) -> Decimal? {
        guard let origen = indice(desde), let destino = indice(hasta) else { return nil }
        guard origen > 0 else { return nil }
        return redondear(monto * destino / origen)
    }

    /// Cuánto compra hoy un peso de aquella fecha. `0.78` = "un peso de agosto
    /// pasado compra 78 centavos de hoy".
    ///
    /// Es la frase que más rápido le explica la inflación a alguien: más que
    /// cualquier gráfico.
    static func poderDeCompra(
        de fecha: Date,
        a hoy: Date,
        indice: (Date) -> Decimal?
    ) -> Decimal? {
        guard let origen = indice(fecha), let destino = indice(hoy), destino > 0 else { return nil }
        var resultado = Decimal()
        var bruto = origen / destino
        NSDecimalRound(&resultado, &bruto, 4, .plain)
        return resultado
    }

    /// Variación real: cuánto cambió algo **descontando la inflación**.
    ///
    /// El caso que le importa al usuario: "tu sueldo subió 25%, la inflación fue
    /// 33,5% → perdiste 6,4% real". Sin esto, un aumento nominal parece una
    /// mejora cuando puede ser una pérdida.
    static func variacionReal(
        anterior: Decimal,
        fechaAnterior: Date,
        actual: Decimal,
        fechaActual: Date,
        indice: (Date) -> Decimal?
    ) -> Decimal? {
        guard anterior > 0,
              let anteriorEnMonedaDeHoy = llevar(anterior, desde: fechaAnterior, hasta: fechaActual, indice: indice),
              anteriorEnMonedaDeHoy > 0 else { return nil }
        var resultado = Decimal()
        var bruto = (actual - anteriorEnMonedaDeHoy) / anteriorEnMonedaDeHoy
        NSDecimalRound(&resultado, &bruto, 4, .plain)
        return resultado
    }

    /// Dos centavos, como todo el dinero de la app.
    private static func redondear(_ d: Decimal) -> Decimal {
        var origen = d
        var out = Decimal()
        NSDecimalRound(&out, &origen, 2, .plain)
        return out
    }
}
