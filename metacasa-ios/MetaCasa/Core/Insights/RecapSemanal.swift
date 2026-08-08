import Foundation

/// El resumen de la semana, que la app trae sin que se lo pidan.
///
/// ─── POR QUÉ ───────────────────────────────────────────────────────────────
/// Un asistente al que hay que ir a buscar se usa dos veces y se abandona. El
/// 60% de las interacciones del asistente de Bank of America son proactivas, y
/// Monarch volvió su recap semanal el eje del producto. Es la diferencia entre
/// una app que registra y una que avisa.
///
/// Semanal y no mensual a propósito: con inflación alta, enterarse el día 30 de
/// que el mes se fue de cauce llega tarde. En una semana todavía se puede hacer
/// algo.
struct RecapSemanal: Sendable, Equatable {
    let desde: Date
    let hasta: Date
    let gasto: Decimal
    let gastoPrevio: Decimal
    let ingresos: Decimal
    /// Variación **descontando la inflación**. `nil` si no hay índice.
    ///
    /// Es el número que importa: con 33,5% anual, "gastaste 3% más que la
    /// semana pasada" puede ser gastaste menos en términos reales.
    let variacionReal: Decimal?
    /// Categorías de la semana, de mayor a menor.
    let porCategoria: [(categoria: String, monto: Decimal)]
    /// La que más subió contra la semana anterior, que es el titular útil:
    /// no "gastaste más" sino **en qué**.
    let mayorSubida: (categoria: String, delta: Decimal)?
    /// Días de la semana sin ningún movimiento cargado. Muchos = el dato no es
    /// confiable y conviene decirlo en vez de dar un veredicto.
    let diasSinRegistro: Int

    static func == (a: RecapSemanal, b: RecapSemanal) -> Bool {
        a.desde == b.desde && a.hasta == b.hasta && a.gasto == b.gasto
    }

    /// `true` si el usuario gastó menos que la semana anterior **en términos
    /// reales**.
    var mejoro: Bool {
        if let real = variacionReal { return real < 0 }
        return gasto < gastoPrevio
    }
}

enum CalculadoraDeRecap {

    /// Ventana del recap: los últimos 7 días contra los 7 anteriores.
    ///
    /// Se eligió una ventana móvil y no la semana calendario cerrada para que el
    /// recap sirva cualquier día, y no sólo los lunes. El costo es que "la
    /// semana" no coincide con el lunes-a-domingo mental de algunos; la ventaja
    /// es que la app dice algo útil el día que la abrís.
    static let dias = 7

    /// Devuelve `nil` cuando no hay con qué decir nada: sin movimientos en
    /// ninguna de las dos ventanas, cualquier veredicto sería inventado.
    static func calcular(
        movimientos: [Transaction],
        hoy: Date = Date(),
        calendario: Calendar = .current,
        indice: ((Date) -> Decimal?)? = nil
    ) -> RecapSemanal? {
        let finDeHoy = calendario.startOfDay(for: hoy)
        guard let desde = calendario.date(byAdding: .day, value: -(dias - 1), to: finDeHoy),
              let desdePrevio = calendario.date(byAdding: .day, value: -(dias * 2 - 1), to: finDeHoy),
              let hastaPrevio = calendario.date(byAdding: .day, value: -dias, to: finDeHoy)
        else { return nil }

        // Mover plata entre cuentas propias no es gasto: sumarlo infla los dos
        // lados a la vez y el recap diría cualquier cosa.
        let reales = movimientos.excludingTransfers

        func enRango(_ inicio: Date, _ fin: Date) -> [Transaction] {
            reales.filter { tx in
                let d = calendario.startOfDay(for: tx.date)
                return d >= inicio && d <= fin
            }
        }

        let semana = enRango(desde, finDeHoy)
        let previa = enRango(desdePrevio, hastaPrevio)
        guard !semana.isEmpty || !previa.isEmpty else { return nil }

        let gasto = semana.filter { $0.type == .gasto }.reduce(Decimal.zero) { $0 + $1.amount }
        let gastoPrevio = previa.filter { $0.type == .gasto }.reduce(Decimal.zero) { $0 + $1.amount }
        let ingresos = semana.filter { $0.type == .ingreso }.reduce(Decimal.zero) { $0 + $1.amount }

        var porCat: [String: Decimal] = [:]
        for tx in semana where tx.type == .gasto { porCat[tx.category, default: 0] += tx.amount }
        var porCatPrevio: [String: Decimal] = [:]
        for tx in previa where tx.type == .gasto { porCatPrevio[tx.category, default: 0] += tx.amount }

        let ordenadas = porCat
            .map { (categoria: $0.key, monto: $0.value) }
            .sorted { $0.monto > $1.monto }

        // La que más subió en PESOS, no en porcentaje: un 300% sobre $500 no le
        // mueve el mes a nadie, y aparecería primero en un ranking por %.
        let subidas = porCat.map { (categoria: $0.key, delta: $0.value - (porCatPrevio[$0.key] ?? 0)) }
            .filter { $0.delta > 0 }
            .sorted { $0.delta > $1.delta }

        // Variación real: se toma el punto medio de cada ventana como fecha de
        // referencia, que es el promedio de cuándo se gastó.
        var real: Decimal?
        if let indice, gastoPrevio > 0,
           let medioPrevio = calendario.date(byAdding: .day, value: -(dias + dias / 2), to: finDeHoy),
           let medioActual = calendario.date(byAdding: .day, value: -(dias / 2), to: finDeHoy) {
            real = Reexpresion.variacionReal(
                anterior: gastoPrevio, fechaAnterior: medioPrevio,
                actual: gasto, fechaActual: medioActual, indice: indice)
        }

        let diasConMovimiento = Set(semana.map { calendario.startOfDay(for: $0.date) }).count

        return RecapSemanal(
            desde: desde,
            hasta: finDeHoy,
            gasto: gasto,
            gastoPrevio: gastoPrevio,
            ingresos: ingresos,
            variacionReal: real,
            porCategoria: Array(ordenadas.prefix(5)),
            mayorSubida: subidas.first,
            diasSinRegistro: max(0, dias - diasConMovimiento)
        )
    }
}
