import Foundation
import KeychainAccess

/// Wrapper simple sobre KeychainAccess con la accesibilidad más restrictiva
/// (sólo desbloqueable cuando el device tiene passcode y sólo en este device).
enum KeychainStore {
    private static let keychain: Keychain = {
        Keychain(service: Config.bundleId)
            .synchronizable(false)
            .accessibility(.whenPasscodeSetThisDeviceOnly)
    }()

    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        do {
            try keychain.set(value, key: key)
            return true
        } catch {
            return false
        }
    }

    static func get(_ key: String) -> String? {
        try? keychain.get(key)
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        do {
            try keychain.remove(key)
            return true
        } catch {
            return false
        }
    }

    static func clearAll() {
        try? keychain.removeAll()
    }
}

/// Keys usadas en toda la app. Mantener en un solo lugar para evitar typos.
enum KeychainKey {
    static let appPIN = "app_pin"              // PIN fallback si biometría falla
    static let lastLoginEmail = "last_email"   // prefill login screen
}
