import Foundation
import StoreKit

/// Maneja el trial de 7 días.
///
/// **Ancla del trial**: `AppTransaction.originalPurchaseDate` — la fecha en que
/// el Apple ID descargó la app por primera vez. Sobrevive reinstalaciones y
/// borrado de datos porque está atada a la cuenta de App Store, NO al
/// dispositivo. Es el método recomendado por Apple para trials a nivel app.
///
/// **Fallback**: en entornos donde `AppTransaction` aún no está verificado
/// (algunos casos de sandbox/TestFlight en el primer arranque), se usa la
/// primera fecha de uso persistida en Keychain. Es best-effort; el ancla real
/// es `AppTransaction`.
enum TrialManager {

    /// Duración exacta del trial: 7 días.
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    private static let keychainKey = "trial_first_launch_iso"

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Fecha de inicio del trial (descarga del Apple ID, o fallback Keychain).
    static func trialStartDate() async -> Date {
        if let d = await appStoreOriginalPurchaseDate() {
            return d
        }
        return keychainFirstLaunchDate()
    }

    /// Momento exacto en que vence el trial.
    static func trialEndDate() async -> Date {
        await trialStartDate().addingTimeInterval(trialDuration)
    }

    /// `true` mientras el trial siga vigente.
    static func isInTrial() async -> Bool {
        await Date() < trialEndDate()
    }

    /// Días enteros restantes de trial (0 si ya venció).
    static func daysRemaining() async -> Int {
        let secs = await trialEndDate().timeIntervalSinceNow
        guard secs > 0 else { return 0 }
        return max(1, Int(ceil(secs / 86_400)))
    }

    // MARK: - Fuentes

    private static func appStoreOriginalPurchaseDate() async -> Date? {
        do {
            let result = try await AppTransaction.shared
            if case .verified(let appTransaction) = result {
                return appTransaction.originalPurchaseDate
            }
            return nil
        } catch {
            return nil
        }
    }

    private static func keychainFirstLaunchDate() -> Date {
        if let stored = KeychainStore.get(keychainKey),
           let date = iso.date(from: stored) {
            return date
        }
        let now = Date()
        KeychainStore.set(iso.string(from: now), for: keychainKey)
        return now
    }
}
