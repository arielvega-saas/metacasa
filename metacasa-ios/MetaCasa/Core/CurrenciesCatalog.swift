import Foundation

struct CurrencyInfo: Hashable, Sendable, Identifiable {
    var id: String { code }
    let code: String        // "USD"
    let symbol: String      // "U$S"
    let name: String        // "Dólar Estadounidense"
    let shortName: String   // "Dólar"
    let flag: String        // "🇺🇸"
    let region: Region

    enum Region: String, CaseIterable, Sendable {
        case latam = "América Latina"
        case northAmerica = "Norte América"
        case europe = "Europa"
        case asiaPacific = "Asia · Pacífico"
        case middleEastAfrica = "Medio Oriente · África"
    }
}

enum CurrenciesCatalog {
    static let all: [CurrencyInfo] = [
        // América Latina
        .init(code: "ARS", symbol: "$",    name: "Peso Argentino",       shortName: "Peso ARS",  flag: "🇦🇷", region: .latam),
        .init(code: "BRL", symbol: "R$",   name: "Real Brasileño",       shortName: "Real",      flag: "🇧🇷", region: .latam),
        .init(code: "CLP", symbol: "CL$",  name: "Peso Chileno",         shortName: "Peso CLP",  flag: "🇨🇱", region: .latam),
        .init(code: "COP", symbol: "CO$",  name: "Peso Colombiano",      shortName: "Peso COP",  flag: "🇨🇴", region: .latam),
        .init(code: "MXN", symbol: "MX$",  name: "Peso Mexicano",        shortName: "Peso MXN",  flag: "🇲🇽", region: .latam),
        .init(code: "PEN", symbol: "S/.",  name: "Sol Peruano",          shortName: "Sol",       flag: "🇵🇪", region: .latam),
        .init(code: "UYU", symbol: "$U",   name: "Peso Uruguayo",        shortName: "Peso UYU",  flag: "🇺🇾", region: .latam),
        .init(code: "PYG", symbol: "₲",    name: "Guaraní",              shortName: "Guaraní",   flag: "🇵🇾", region: .latam),
        .init(code: "BOB", symbol: "Bs.",  name: "Boliviano",            shortName: "Boliviano", flag: "🇧🇴", region: .latam),
        .init(code: "VES", symbol: "Bs.S", name: "Bolívar Venezolano",   shortName: "Bolívar",   flag: "🇻🇪", region: .latam),
        // Norte América
        .init(code: "USD", symbol: "U$S",  name: "Dólar Estadounidense", shortName: "Dólar",     flag: "🇺🇸", region: .northAmerica),
        .init(code: "CAD", symbol: "CA$",  name: "Dólar Canadiense",     shortName: "Dólar CA",  flag: "🇨🇦", region: .northAmerica),
        // Europa
        .init(code: "EUR", symbol: "€",    name: "Euro",                 shortName: "Euro",      flag: "🇪🇺", region: .europe),
        .init(code: "GBP", symbol: "£",    name: "Libra Esterlina",      shortName: "Libra",     flag: "🇬🇧", region: .europe),
        .init(code: "CHF", symbol: "Fr.",  name: "Franco Suizo",         shortName: "Franco",    flag: "🇨🇭", region: .europe),
        .init(code: "SEK", symbol: "kr",   name: "Corona Sueca",         shortName: "Corona SE", flag: "🇸🇪", region: .europe),
        .init(code: "NOK", symbol: "kr",   name: "Corona Noruega",       shortName: "Corona NO", flag: "🇳🇴", region: .europe),
        .init(code: "DKK", symbol: "kr",   name: "Corona Danesa",        shortName: "Corona DK", flag: "🇩🇰", region: .europe),
        .init(code: "PLN", symbol: "zł",   name: "Złoty Polaco",         shortName: "Złoty",     flag: "🇵🇱", region: .europe),
        // Asia · Pacífico
        .init(code: "JPY", symbol: "¥",    name: "Yen Japonés",          shortName: "Yen",       flag: "🇯🇵", region: .asiaPacific),
        .init(code: "CNY", symbol: "CN¥",  name: "Yuan Chino",           shortName: "Yuan",      flag: "🇨🇳", region: .asiaPacific),
        .init(code: "KRW", symbol: "₩",    name: "Won Surcoreano",       shortName: "Won",       flag: "🇰🇷", region: .asiaPacific),
        .init(code: "INR", symbol: "₹",    name: "Rupia India",          shortName: "Rupia",     flag: "🇮🇳", region: .asiaPacific),
        .init(code: "AUD", symbol: "A$",   name: "Dólar Australiano",    shortName: "Dólar AU",  flag: "🇦🇺", region: .asiaPacific),
        .init(code: "NZD", symbol: "NZ$",  name: "Dólar Neozelandés",    shortName: "Dólar NZ",  flag: "🇳🇿", region: .asiaPacific),
        .init(code: "SGD", symbol: "S$",   name: "Dólar Singapurense",   shortName: "Dólar SG",  flag: "🇸🇬", region: .asiaPacific),
        .init(code: "HKD", symbol: "HK$",  name: "Dólar de Hong Kong",   shortName: "Dólar HK",  flag: "🇭🇰", region: .asiaPacific),
        // Medio Oriente · África
        .init(code: "AED", symbol: "د.إ",  name: "Dírham Emiratí",       shortName: "Dírham",    flag: "🇦🇪", region: .middleEastAfrica),
        .init(code: "ILS", symbol: "₪",    name: "Séquel Israelí",       shortName: "Séquel",    flag: "🇮🇱", region: .middleEastAfrica),
        .init(code: "ZAR", symbol: "R",    name: "Rand Sudafricano",     shortName: "Rand",      flag: "🇿🇦", region: .middleEastAfrica),
    ]

    static func info(for code: String) -> CurrencyInfo? {
        all.first { $0.code == code.uppercased() }
    }

    static func flag(for code: String) -> String {
        info(for: code)?.flag ?? "💱"
    }

    static func name(for code: String) -> String {
        info(for: code)?.name ?? code
    }

    static func symbol(for code: String) -> String {
        info(for: code)?.symbol ?? code
    }

    /// Monedas agrupadas por región para el picker.
    static var byRegion: [(CurrencyInfo.Region, [CurrencyInfo])] {
        CurrencyInfo.Region.allCases.map { region in
            (region, all.filter { $0.region == region })
        }
    }
}
