import Foundation
import SwiftUI
import Observation

/// Preferencia de apariencia del usuario. Respeta el sistema por default (HIG
/// de Apple). El usuario puede forzar dark o light desde Settings.
enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Clave de localización para `Text(...)`. SwiftUI resuelve usando el
    /// environment locale al render time.
    var labelKey: LocalizedStringKey {
        switch self {
        case .system: "appearance.option.system"
        case .light:  "appearance.option.light"
        case .dark:   "appearance.option.dark"
        }
    }

    /// Versión String localizada para acceso fuera de Views.
    var label: String {
        switch self {
        case .system: String(localized: "appearance.option.system")
        case .light:  String(localized: "appearance.option.light")
        case .dark:   String(localized: "appearance.option.dark")
        }
    }

    var systemIcon: String {
        switch self {
        case .system: "iphone.gen3"
        case .light:  "sun.max.fill"
        case .dark:   "moon.fill"
        }
    }

    /// Convierte a `ColorScheme?` para `.preferredColorScheme`.
    /// `nil` = seguir el sistema.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

@MainActor
@Observable
final class AppearanceManager {
    static let shared = AppearanceManager()

    var preference: AppearancePreference {
        didSet { AppearanceStorage.write(preference) }
    }

    private init() {
        self.preference = AppearanceStorage.read()
    }
}

/// Storage nonisolated para que el toggle pueda leerse sin MainActor hop.
enum AppearanceStorage {
    private static let key = "app_appearance_preference"

    static func read() -> AppearancePreference {
        if let raw = UserDefaults.standard.string(forKey: key),
           let value = AppearancePreference(rawValue: raw) {
            return value
        }
        // Default histórico de la app = dark. El usuario puede cambiar.
        return .dark
    }

    static func write(_ value: AppearancePreference) {
        UserDefaults.standard.set(value.rawValue, forKey: key)
    }
}
