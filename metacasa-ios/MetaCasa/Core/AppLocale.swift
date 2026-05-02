import Foundation
import Observation
import SwiftUI

/// Catálogo de locales soportados por MetaCasa.
/// Orden: el primero es el default de desarrollo (es-AR) por el mercado core LatAm.
enum SupportedLocale: String, CaseIterable, Identifiable, Hashable, Sendable {
    case system
    case spanishAR = "es-AR"
    case spanishES = "es-ES"
    case englishUS = "en-US"
    case portugueseBR = "pt-BR"

    var id: String { rawValue }

    /// Identifier canonico para `Locale(identifier:)`.
    var localeIdentifier: String {
        switch self {
        case .system:       return Locale.current.identifier
        case .spanishAR:    return "es_AR"
        case .spanishES:    return "es_ES"
        case .englishUS:    return "en_US"
        case .portugueseBR: return "pt_BR"
        }
    }

    /// Foundation `Locale` listo para formatters.
    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        default:      return Locale(identifier: localeIdentifier)
        }
    }

    /// Label humano — se muestra en el propio idioma (native name).
    var nativeLabel: String {
        switch self {
        case .system:       return "Predeterminado del sistema"
        case .spanishAR:    return "Español (Argentina)"
        case .spanishES:    return "Español (España)"
        case .englishUS:    return "English (US)"
        case .portugueseBR: return "Português (Brasil)"
        }
    }

    var flag: String {
        switch self {
        case .system:       return "🌐"
        case .spanishAR:    return "🇦🇷"
        case .spanishES:    return "🇪🇸"
        case .englishUS:    return "🇺🇸"
        case .portugueseBR: return "🇧🇷"
        }
    }
}

/// Holder central del locale efectivo.
///
/// Diseño:
/// - `UserDefaults` como single source of truth (thread-safe por APIs de Apple).
/// - Los formatters (`Money`) leen estáticamente sin hoppear al MainActor.
/// - Las Views usan el observable `AppLocaleManager.shared` para reaccionar a
///   cambios y propagan `.environment(\.locale, ...)` al root view.
@MainActor
@Observable
final class AppLocaleManager {
    static let shared = AppLocaleManager()

    var current: SupportedLocale {
        didSet { AppLocaleStorage.write(current) }
    }

    var effectiveLocale: Locale { current.locale }

    private init() {
        self.current = AppLocaleStorage.read()
    }
}

/// Storage de bajo nivel (nonisolated) para que los formatters lean el override
/// sin saltar al MainActor.
enum AppLocaleStorage {
    private static let key = "app_locale_override"

    static func read() -> SupportedLocale {
        if let raw = UserDefaults.standard.string(forKey: key),
           let v = SupportedLocale(rawValue: raw) {
            return v
        }
        return .system
    }

    static func write(_ value: SupportedLocale) {
        UserDefaults.standard.set(value.rawValue, forKey: key)
    }

    /// Locale efectivo a usar en formatters. Nonisolated, thread-safe.
    static var effectiveLocale: Locale {
        read().locale
    }
}
