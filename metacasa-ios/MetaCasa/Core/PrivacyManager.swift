import Foundation
import Observation

/// Gestor de modo privacidad — blur automático de montos en la UI.
/// Port de `privacyMode` del web (App.jsx:3249-3256). Persiste en UserDefaults.
@MainActor
@Observable
final class PrivacyManager {
    static let shared = PrivacyManager()

    private let defaultsKey = "app_privacy_mode"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: defaultsKey) }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: defaultsKey)
    }

    func toggle() { isEnabled.toggle() }

    /// Devuelve `original` si privacy OFF, o un string ofuscado "••••" si privacy ON.
    func obfuscate(_ original: String) -> String {
        isEnabled ? "••••" : original
    }
}
