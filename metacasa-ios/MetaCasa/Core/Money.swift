import Foundation

/// Formatter centralizado de dinero + parsing robusto.
///
/// Usa `FormatStyle` moderno de Swift (iOS 15+). Respeta el locale efectivo
/// de la app (override del usuario > locale del sistema) y el currency code
/// del hogar actual.
///
/// Ejemplos:
///   Money.format(1234.56, currency: "ARS", locale: Locale(identifier: "es_AR"))
///     → "$ 1.234,56"
///   Money.format(1234.56, currency: "USD", locale: Locale(identifier: "en_US"))
///     → "$1,234.56"
///   Money.format(1234.56, currency: "EUR", locale: Locale(identifier: "es_ES"))
///     → "1.234,56 €"
enum Money {
    /// Estilo de presentación.
    enum Style {
        /// Sin decimales (estilo LatAm para montos grandes, UX limpia). `$ 1.234`
        case compact
        /// Con 2 decimales (exacto). `$ 1.234,56`
        case precise
        /// Auto: compact si el monto es entero, precise si tiene fracción.
        case auto
        /// Notación compacta con sufijos (K/M/B) según locale. `$4,4 M` / `$15 K`.
        /// Útil para celdas chicas (calendar, widgets, charts).
        case abbreviated
    }

    /// Formatea un monto como moneda según locale + código ISO 4217.
    static func format(
        _ amount: Decimal,
        currency: String,
        style: Style = .compact,
        showSign: Bool = false,
        locale: Locale? = nil
    ) -> String {
        let loc = locale ?? Self.currentLocale()

        let base: String
        if case .abbreviated = style {
            // Notación abreviada con sufijos K/M/B/T (universal, no requiere iOS 18).
            // Ej: 4_399_630 → "$4,4M"; 15_000 → "$15K"; 999 → "$999".
            let abs = (amount as NSDecimalNumber).doubleValue.magnitude
            let (divisor, suffix): (Decimal, String) = {
                switch abs {
                case 1_000_000_000_000...: return (1_000_000_000_000, "T")
                case 1_000_000_000...:     return (1_000_000_000, "B")
                case 1_000_000...:         return (1_000_000, "M")
                case 1_000...:             return (1_000, "K")
                default:                   return (1, "")
                }
            }()
            let scaled = amount / divisor
            let fracDigits = suffix.isEmpty ? 0 : (abs.truncatingRemainder(dividingBy: Double(truncating: divisor as NSNumber)) > 0 ? 1 : 0)
            let formatStyle = Decimal.FormatStyle.Currency(code: currency, locale: loc)
                .precision(.fractionLength(fracDigits...fracDigits))
            base = scaled.formatted(formatStyle) + suffix
        } else {
            // Determinar fracción según estilo
            let (minFrac, maxFrac): (Int, Int) = {
                switch style {
                case .compact: return (0, 0)
                case .precise: return (2, 2)
                case .auto:    return hasFraction(amount) ? (2, 2) : (0, 0)
                case .abbreviated: return (0, 0) // unreachable
                }
            }()
            let formatStyle = Decimal.FormatStyle.Currency(code: currency, locale: loc)
                .precision(.fractionLength(minFrac...maxFrac))
            base = amount.formatted(formatStyle)
        }

        // Agregar signo '+' si corresponde (para ingresos/aportes positivos en UIs)
        if showSign && amount > 0 {
            return "+\(base)"
        }
        return base
    }

    /// Formatea un número puro (sin símbolo de moneda) respetando el locale.
    /// Útil para inputs, totales internos, etc.
    static func formatNumber(
        _ value: Decimal,
        fractionDigits: Int = 0,
        locale: Locale? = nil
    ) -> String {
        let loc = locale ?? Self.currentLocale()
        return value.formatted(
            .number
                .locale(loc)
                .precision(.fractionLength(fractionDigits...fractionDigits))
                .grouping(.automatic)
        )
    }

    /// Parsea un string con formato de moneda local al Decimal correspondiente.
    /// Tolera símbolos ($, US$, €, R$, ARS, USD), separadores de miles y decimales
    /// en ambas convenciones (es-AR `1.234,56` y en-US `1,234.56`).
    ///
    /// **Orden de estrategias**:
    /// 1. Heurística basada en el ÚLTIMO separador (más confiable — no depende
    ///    del locale y maneja ambos formatos correctamente). Ej: `-25000.00` →
    ///    25000 exacto. `1.234,56` → 1234.56. `1,234.56` → 1234.56.
    /// 2. NumberFormatter con el locale del caller (para strings con símbolos
    ///    raros que la heurística no capta).
    /// 3. Decimal(string:) — parser C-locale como último recurso.
    static func parse(_ input: String, locale: Locale? = nil) -> Decimal? {
        let loc = locale ?? Self.currentLocale()

        let stripped = input
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "U$S", with: "")
            .replacingOccurrences(of: "US$", with: "")
            .replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: "ARS", with: "")
            .replacingOccurrences(of: "USD", with: "")
            .replacingOccurrences(of: "EUR", with: "")
            .replacingOccurrences(of: "BRL", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "") // NBSP
            .trimmingCharacters(in: .whitespaces)

        // 1. Heurística — más robusta para CSV y entradas variadas.
        if let h = parseHeuristic(stripped) {
            return h
        }

        // 2. NumberFormatter con locale.
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = loc
        if let n = nf.number(from: stripped) {
            return n.decimalValue
        }

        // 3. Último recurso: parser C-locale (punto como decimal).
        return Decimal(string: stripped)
    }

    /// Heurística: el ÚLTIMO separador (. o ,) es el decimal; los anteriores son miles.
    private static func parseHeuristic(_ s: String) -> Decimal? {
        let lastDot = s.lastIndex(of: ".")
        let lastComma = s.lastIndex(of: ",")
        let decimalIndex: String.Index?
        switch (lastDot, lastComma) {
        case (nil, nil):          decimalIndex = nil
        case (let d?, nil):       decimalIndex = d
        case (nil, let c?):       decimalIndex = c
        case (let d?, let c?):    decimalIndex = d > c ? d : c
        }

        var normalized = s
        if let idx = decimalIndex {
            let intPart = s[..<idx]
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
            let fracPart = s[s.index(after: idx)...]
            normalized = "\(intPart).\(fracPart)"
        } else {
            normalized = s
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
        }
        return Decimal(string: normalized)
    }

    private static func hasFraction(_ amount: Decimal) -> Bool {
        var rounded = Decimal()
        var value = amount
        NSDecimalRound(&rounded, &value, 0, .plain)
        return amount != rounded
    }

    /// Locale efectivo global (lee override del usuario o cae a system).
    /// Nonisolated — seguro desde cualquier contexto.
    private static func currentLocale() -> Locale {
        AppLocaleStorage.effectiveLocale
    }
}
