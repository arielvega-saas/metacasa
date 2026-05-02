import Foundation

/// Façade legacy. Mantenida para no romper callers — delega en `Money`.
/// NUEVO CÓDIGO: usar `Money` directamente.
enum CurrencyFormatter {
    /// Formatea un Decimal como moneda (compact = 0 decimales) respetando locale.
    static func format(
        _ amount: Decimal,
        currency: String = "USD",
        showSign: Bool = false,
        decimals: Bool = false,
        locale: Locale? = nil
    ) -> String {
        Money.format(
            amount,
            currency: currency,
            style: decimals ? .precise : .compact,
            showSign: showSign,
            locale: locale
        )
    }

    /// Parsea un string con formato de moneda local al Decimal correspondiente.
    static func parse(_ str: String, locale: Locale? = nil) -> Decimal? {
        Money.parse(str, locale: locale)
    }
}
