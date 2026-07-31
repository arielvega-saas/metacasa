import Foundation

/// Montos sugeridos para fondear una meta de un toque.
///
/// Patrón #8 del `PLAN_NIVEL_PRO.md` (Nubank Cajitas / Monzo Pots). Hoy aportar a una meta cuesta cinco
/// pasos: entrar al detalle, abrir el sheet, tipear el monto, guardar, volver. Esa fricción es la razón
/// por la que las metas se abandonan. Con montos sugeridos, el caso común es **un toque**.
///
/// Las sugerencias se derivan de lo que **falta**, no del objetivo total: si faltan $1.000 no tiene
/// sentido ofrecer "$5.000" porque sobrepasaría la meta, y ofrecer "10% del objetivo" da números feos
/// que nadie elige.
enum GoalQuickFund {

    /// Un monto sugerido, ya listo para mostrar.
    struct Suggestion: Equatable, Identifiable, Sendable {
        let amount: Decimal
        /// La sugerencia que completa la meta exactamente. La UI la destaca.
        let completesGoal: Bool
        var id: String { "\(amount)-\(completesGoal)" }
    }

    /// Devuelve hasta 3 sugerencias para una meta, de menor a mayor.
    ///
    /// Devuelve vacío cuando no hay nada que aportar (meta ya cumplida o datos inválidos): la UI no
    /// debe mostrar chips de fondeo sobre una meta completa.
    static func suggestions(current: Decimal, target: Decimal) -> [Suggestion] {
        let remaining = target - current
        guard remaining > 0 else { return [] }

        // Un cuarto y la mitad de lo que falta, redondeados a un escalón "lindo" según la magnitud.
        // Se redondea HACIA ABAJO para no proponer nunca más que la fracción pedida.
        var amounts: [Decimal] = []
        for fraction in [Decimal(4), Decimal(2)] {
            let raw = remaining / fraction
            let rounded = roundedDown(raw)
            if rounded > 0 && rounded < remaining {
                amounts.append(rounded)
            }
        }

        // Deduplicar conservando el orden (con montos chicos, un cuarto y la mitad pueden coincidir).
        var seen: Set<Decimal> = []
        var unique = amounts.filter { seen.insert($0).inserted }
        unique.sort()

        var result = unique.map { Suggestion(amount: $0, completesGoal: false) }
        // La última siempre completa la meta: es la acción que el usuario más quiere cuando está cerca.
        result.append(Suggestion(amount: remaining, completesGoal: true))
        return result
    }

    /// Redondea hacia abajo a un escalón derivado de la magnitud del número.
    ///
    /// 1.234 → 1.200 · 450 → 450 · 45 → 45 · 7 → 7
    ///
    /// El escalón es 10^(dígitos−2) para que la sugerencia tenga a lo sumo dos cifras significativas:
    /// eso es lo que hace que se lea como un monto elegido por una persona y no calculado por una
    /// máquina. Con menos de 3 dígitos el escalón queda en 1 y el número pasa entero.
    static func roundedDown(_ value: Decimal) -> Decimal {
        guard value > 0 else { return 0 }

        // Cantidad de dígitos de la parte entera, contada en Decimal para no perder precisión
        // pasando por Double (un monto en ARS puede ser grande).
        var digits = 0
        var magnitude = Decimal(1)
        while magnitude <= value {
            magnitude *= 10
            digits += 1
        }
        guard digits > 2 else {
            // Números chicos: se trunca a entero y listo.
            return floored(value)
        }

        var step = Decimal(1)
        for _ in 0..<(digits - 2) { step *= 10 }

        let units = floored(value / step)
        return units * step
    }

    /// Parte entera de un Decimal, redondeando hacia abajo.
    private static func floored(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .down)
        return output
    }
}
