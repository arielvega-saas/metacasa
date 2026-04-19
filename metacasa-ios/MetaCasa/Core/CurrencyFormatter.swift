import Foundation

enum CurrencyFormatter {
    /// Formatea un Decimal como moneda. No usa decimales por default (estilo AR/LatAm).
    static func format(
        _ amount: Decimal,
        currency: String = "USD",
        showSign: Bool = false,
        decimals: Bool = false,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = decimals ? 2 : 0
        formatter.maximumFractionDigits = decimals ? 2 : 0
        formatter.locale = locale

        let str = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        if showSign && amount > 0 {
            return "+\(str)"
        }
        return str
    }

    /// Parsea un string con formato de moneda local al Decimal correspondiente.
    /// Tolera símbolos, separadores de miles y decimales.
    static func parse(_ str: String, locale: Locale = .current) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        let cleaned = str
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "U$S", with: "")
            .replacingOccurrences(of: "€", with: "")
        if let n = formatter.number(from: cleaned) {
            return n.decimalValue
        }
        // Fallback: reemplazar coma por punto (parse tipo ingles)
        let normalized = cleaned.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }
}
