import Foundation

/// Presets iniciales (espejando los de la PWA).
enum CategoryCatalog {
    static let defaultGastos: [String] = [
        "Vivienda", "Transporte", "Salud", "Ocio", "Alimentación", "Servicios"
    ]
    static let defaultIngresos: [String] = [
        "Sueldo", "Inversiones", "Ventas"
    ]

    static let defaultEmojis: [String: String] = [
        "Vivienda": "🏠", "Transporte": "🚗", "Salud": "🏥",
        "Ocio": "🎮", "Alimentación": "🍽️", "Servicios": "⚡",
        "Sueldo": "💼", "Inversiones": "📈", "Ventas": "🛍️"
    ]

    static let emojiPalette: [String] = [
        "🏠","🚗","🏥","🎮","🍽️","⚡","💼","📈","🛍️","🎓","✈️","🏋️",
        "🐶","🐱","🌿","🎵","📱","💊","🛒","🎁","🏦","💳","🍕","☕",
        "🚌","⛽","🎬","📚","👕","🏡","🔧","🧹","🌙","☀️","🍺","🎯",
        "💰","💸","🤝","📊","🔑","🏊","🎨","💡","🧘","🌊","🚀","🍎"
    ]

    static func emoji(for category: String) -> String {
        defaultEmojis[category] ?? "📌"
    }
}
