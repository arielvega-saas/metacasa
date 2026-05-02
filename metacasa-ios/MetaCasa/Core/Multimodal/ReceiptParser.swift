import Foundation

/// Resultado de parsear texto OCR de un recibo/ticket.
/// Los campos son opcionales — si el parser no pudo determinar alguno, queda nil
/// y el UI le pide al usuario confirmar/completar antes de crear la tx.
struct ParsedReceipt: Sendable {
    let amount: Decimal?
    let date: Date?
    let merchant: String?
    let currency: String?
    let category: String?
    let rawLines: [String]
}

/// Parser heurístico para extraer monto, fecha y comercio de texto OCR.
/// Si FoundationModels está disponible, refina con LLM (Sprint 3+).
/// Si no, heurísticas determinísticas.
enum ReceiptParser {
    static func parse(text: String) -> ParsedReceipt {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return ParsedReceipt(
            amount: findAmount(in: lines),
            date: findDate(in: lines),
            merchant: findMerchant(in: lines),
            currency: findCurrency(in: lines),
            category: guessCategory(merchant: findMerchant(in: lines), lines: lines),
            rawLines: lines
        )
    }

    /// Busca el monto total. Heurística: buscar líneas con "total", "importe",
    /// "a pagar" que tengan un número con decimales. Si no hay, el máximo
    /// número con decimales (probable total).
    private static func findAmount(in lines: [String]) -> Decimal? {
        let totalKeywords = ["total", "importe", "a pagar", "subtotal", "son", "amount due"]
        let numberPattern = #"([0-9]{1,6}(?:[.,][0-9]{3})*[.,][0-9]{2})"#
        let regex = try? NSRegularExpression(pattern: numberPattern)

        // Prioridad 1: líneas que contengan palabra clave "total"
        for line in lines {
            let lower = line.lowercased()
            guard totalKeywords.contains(where: { lower.contains($0) }) else { continue }
            let ns = line as NSString
            let matches = regex?.matches(in: line, range: NSRange(location: 0, length: ns.length)) ?? []
            for m in matches {
                let raw = ns.substring(with: m.range(at: 1))
                if let d = normalize(raw), d > 0 { return d }
            }
        }

        // Prioridad 2: el mayor número con decimales en todo el texto.
        var candidates: [Decimal] = []
        for line in lines {
            let ns = line as NSString
            let matches = regex?.matches(in: line, range: NSRange(location: 0, length: ns.length)) ?? []
            for m in matches {
                let raw = ns.substring(with: m.range(at: 1))
                if let d = normalize(raw), d > 0 { candidates.append(d) }
            }
        }
        return candidates.max()
    }

    /// Convierte "1.234,56" (es) o "1,234.56" (en) o "1234.56" (simple) a Decimal.
    private static func normalize(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        // Heurística: si hay ambos ',' y '.', el último es decimal separator.
        if trimmed.contains(",") && trimmed.contains(".") {
            let lastComma = trimmed.lastIndex(of: ",") ?? trimmed.startIndex
            let lastDot = trimmed.lastIndex(of: ".") ?? trimmed.startIndex
            let decimalSeparator: Character = (lastComma > lastDot) ? "," : "."
            let otherSeparator: Character = decimalSeparator == "," ? "." : ","
            let cleaned = trimmed
                .replacingOccurrences(of: String(otherSeparator), with: "")
                .replacingOccurrences(of: String(decimalSeparator), with: ".")
            return Decimal(string: cleaned)
        }
        // Solo coma: asumimos decimal separator (es-AR)
        if trimmed.contains(",") && !trimmed.contains(".") {
            return Decimal(string: trimmed.replacingOccurrences(of: ",", with: "."))
        }
        return Decimal(string: trimmed)
    }

    private static func findDate(in lines: [String]) -> Date? {
        let patterns = [
            #"\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b"#,
            #"\b(\d{4}-\d{2}-\d{2})\b"#
        ]
        let formatters: [DateFormatter] = [
            makeFormatter("dd/MM/yyyy"),
            makeFormatter("dd-MM-yyyy"),
            makeFormatter("dd/MM/yy"),
            makeFormatter("dd-MM-yy"),
            makeFormatter("yyyy-MM-dd"),
            makeFormatter("MM/dd/yyyy", locale: "en_US"),
            makeFormatter("MM-dd-yyyy", locale: "en_US")
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let ns = line as NSString
                let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
                for m in matches {
                    let dateStr = ns.substring(with: m.range(at: 1))
                    for f in formatters {
                        if let d = f.date(from: dateStr), d < Date().addingTimeInterval(86400) {
                            return d
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func findMerchant(in lines: [String]) -> String? {
        // Heurística: primera línea "de verdad" (>3 chars, no solo números).
        return lines.first { line in
            line.count > 3 && line.rangeOfCharacter(from: .letters) != nil
        }
    }

    private static func findCurrency(in lines: [String]) -> String? {
        let text = lines.joined(separator: " ").uppercased()
        if text.contains("USD") || text.contains("US$") { return "USD" }
        if text.contains("EUR") || text.contains("€") { return "EUR" }
        if text.contains("ARS") || text.contains("AR$") { return "ARS" }
        if text.contains("BRL") || text.contains("R$") { return "BRL" }
        if text.contains("MXN") { return "MXN" }
        return nil
    }

    /// Heurística muy simple para adivinar categoría basada en comercio.
    private static func guessCategory(merchant: String?, lines: [String]) -> String? {
        let text = ((merchant ?? "") + " " + lines.joined(separator: " ")).lowercased()
        if text.contains("super") || text.contains("almacen") || text.contains("mercado")
            || text.contains("carrefour") || text.contains("coto") || text.contains("dia")
            || text.contains("jumbo") || text.contains("walmart") {
            return "Alimentación"
        }
        if text.contains("uber") || text.contains("cabify") || text.contains("taxi")
            || text.contains("ypf") || text.contains("shell") || text.contains("axion")
            || text.contains("nafta") || text.contains("subte") || text.contains("colectivo") {
            return "Transporte"
        }
        if text.contains("farmacia") || text.contains("clinica") || text.contains("hospital")
            || text.contains("medico") || text.contains("dentista") {
            return "Salud"
        }
        if text.contains("netflix") || text.contains("spotify") || text.contains("disney")
            || text.contains("hbo") || text.contains("youtube") || text.contains("apple") {
            return "Suscripciones"
        }
        if text.contains("luz") || text.contains("gas") || text.contains("agua")
            || text.contains("internet") || text.contains("telecom") || text.contains("movistar")
            || text.contains("personal") || text.contains("claro") {
            return "Servicios"
        }
        if text.contains("zara") || text.contains("h&m") || text.contains("nike")
            || text.contains("adidas") || text.contains("ropa") {
            return "Ropa"
        }
        return nil
    }

    private static func makeFormatter(_ format: String, locale: String = "es_AR") -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: locale)
        return f
    }
}
