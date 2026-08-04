import Foundation
import StoreKit

/// Maneja el trial de 7 días.
///
/// **Ancla del trial**: `AppTransaction.originalPurchaseDate` — la fecha en que
/// el Apple ID descargó la app por primera vez. Sobrevive reinstalaciones y
/// borrado de datos porque está atada a la cuenta de App Store, NO al
/// dispositivo. Es el método recomendado por Apple para trials a nivel app.
///
/// **Se pregunta UNA sola vez.** Apenas se conoce, el ancla se persiste en
/// Keychain y todos los arranques siguientes la leen de ahí, sin tocar StoreKit.
/// Esto no es una optimización: `AppTransaction.shared` es **interactivo**. Si el
/// dispositivo no tiene sesión de App Store iniciada, StoreKit abre el diálogo
/// "Iniciar sesión en cuenta de Apple" — y como se llamaba en cada arranque, al
/// cancelarlo volvía a aparecer, en loop, con la app trabada en el splash detrás.
/// Un pedido de credenciales de Apple sin contexto, en una app de finanzas, es
/// además exactamente lo que entrena al usuario a caer en phishing.
///
/// **Fallback**: si `AppTransaction` no está disponible (sandbox/TestFlight en el
/// primer arranque, o el usuario canceló el login), se ancla en la primera fecha
/// de uso. Es best-effort; el ancla preferida sigue siendo `AppTransaction`.
enum TrialManager {

    /// Duración exacta del trial: 7 días.
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    /// Internal (no private) para que los tests puedan sembrar y restaurar el ancla.
    static let keychainKey = "trial_first_launch_iso"

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Fecha de inicio del trial (descarga del Apple ID, o fallback primera apertura).
    ///
    /// El ancla se resuelve **una sola vez** y queda en Keychain. Mientras haya ancla
    /// guardada no se consulta StoreKit: el arranque no depende de la red ni puede
    /// disparar el diálogo de login de Apple.
    static func trialStartDate() async -> Date {
        if let stored = storedAnchor() {
            return stored
        }
        // Primer arranque en este dispositivo: es el único momento en que se pregunta.
        // Si Apple no contesta (o el usuario cancela el login) se ancla en ahora, que
        // es lo mismo que hacía el fallback anterior.
        let anchor = await appStoreOriginalPurchaseDate() ?? Date()
        persistAnchor(anchor)
        return anchor
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

    /// Cuánto se espera a `AppTransaction` antes de usar el fallback del Keychain.
    ///
    /// Sin tope, la app se colgaba en el splash: `AppTransaction.shared` no vuelve cuando Apple
    /// throttlea, y el `do/catch` no ayuda porque un cuelgue no lanza. 4 segundos es de sobra
    /// cuando StoreKit responde (típico < 1s) y no se nota en un arranque normal.
    private static let appTransactionTimeout: Duration = .seconds(4)

    private static func appStoreOriginalPurchaseDate() async -> Date? {
        // El doble opcional es a propósito: `nil` externo = se acabó el tiempo,
        // `nil` interno = StoreKit contestó que no hay fecha.
        let resultado: Date?? = await withTimeout(appTransactionTimeout) { () -> Date? in
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
        return resultado ?? nil
    }

    /// Ancla ya resuelta, si existe. El Keychain sobrevive a desinstalar la app, así
    /// que reinstalar no regala un trial nuevo.
    static func storedAnchor() -> Date? {
        guard let stored = KeychainStore.get(keychainKey) else { return nil }
        return iso.date(from: stored)
    }

    private static func persistAnchor(_ date: Date) {
        KeychainStore.set(iso.string(from: date), for: keychainKey)
    }
}
