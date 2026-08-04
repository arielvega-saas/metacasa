import Foundation
import Observation
import StoreKit

/// Controla el acceso global a la app bajo el modelo **trial duro**:
///
/// - La app se descarga gratis.
/// - Al primer uso arranca un trial de 7 días (ver `TrialManager`).
/// - Pasados los 7 días, la app queda **completamente bloqueada** hasta que el
///   usuario tenga una suscripción activa (mensual o anual).
///
/// La verificación de suscripción usa StoreKit 2 directamente
/// (`Transaction.currentEntitlements`), así que el gate funciona aunque
/// RevenueCat todavía no esté configurado. RevenueCat solo maneja la UI/flujo
/// de compra en el paywall.
@MainActor
@Observable
final class AccessController {

    enum State: Equatable {
        case loading
        case granted   // trial vigente o suscripción activa
        case locked    // trial vencido y sin suscripción → app inutilizable
    }

    private(set) var state: State = .loading
    private(set) var isSubscribed = false
    private(set) var isInTrial = false
    private(set) var trialDaysRemaining = 0

    /// Product IDs de las suscripciones premium. DEBEN coincidir con los
    /// productos creados en App Store Connect y RevenueCat.
    static let subscriptionProductIDs: Set<String> = [
        "com.metacasa.premium.monthly",
        "com.metacasa.premium.annual"
    ]

    private var updatesTask: Task<Void, Never>?

    /// Arranca el listener de transacciones y hace la primera evaluación.
    /// Idempotente.
    func start() {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                // `StoreKit.Transaction` calificado: la app tiene su propio
                // tipo `Transaction` (modelo financiero) que colisiona.
                for await _ in StoreKit.Transaction.updates {
                    await self?.refresh()
                }
            }
        }
        Task { await refresh() }
    }

    /// Cuánto se espera a StoreKit antes de decidir sin él.
    ///
    /// `Transaction.currentEntitlements` puede no terminar NUNCA: cuando Apple throttlea
    /// (`AppTransaction throttled`, error SKInternal 12), cuando no hay conexión con el App Store,
    /// o cuando la cuenta del dispositivo está en un estado raro. Sin tope, el `for await` queda
    /// colgado, `state` se queda en `.loading` y `RootView` muestra `LaunchView()` **para siempre**:
    /// la app queda inutilizable en el splash, sin error, sin reintento y sin forma de entrar.
    ///
    /// Encontrado el 2026-08-04 en el simulador, pero no es un problema del simulador: el throttle
    /// de StoreKit es del lado de Apple y le puede pasar a cualquier usuario.
    private static let storeKitTimeout: Duration = .seconds(6)

    /// Re-evalúa acceso: suscripción activa O trial vigente.
    ///
    /// El orden importa. El trial se calcula LOCAL (comparación de fechas contra el ancla ya
    /// guardada en Keychain, sin red), así que se resuelve primero y corta: un usuario en trial
    /// entra sin depender de StoreKit para nada. La única excepción es el primerísimo arranque
    /// en el dispositivo, donde `TrialManager` resuelve el ancla una vez y la persiste.
    /// Sólo si el trial venció hace falta preguntar por la suscripción, y esa consulta va acotada.
    func refresh() async {
        let inTrial = await TrialManager.isInTrial()
        let days = await TrialManager.daysRemaining()
        isInTrial = inTrial
        trialDaysRemaining = days

        if inTrial {
            // No se toca StoreKit: el trial alcanza para entrar.
            state = .granted
            return
        }

        let subscribed = await Self.hasActiveSubscriptionBounded()
        isSubscribed = subscribed

        // Si StoreKit no contestó, `subscribed` viene en false y se cae al paywall — que TIENE
        // botón de reintento. Es la salida correcta: no regala acceso (sería el agujero de
        // monetización que ya costó una vez) y tampoco deja la app colgada. Un suscriptor real
        // recupera el acceso apenas StoreKit responde, sin reinstalar nada.
        state = subscribed ? .granted : .locked
    }

    /// `hasActiveSubscription()` con tope de tiempo. Devuelve `false` si StoreKit no contestó.
    private static func hasActiveSubscriptionBounded() async -> Bool {
        await withTimeout(storeKitTimeout) { await hasActiveSubscription() } ?? false
    }

    /// Recorre los entitlements actuales de StoreKit y devuelve `true` si hay
    /// una suscripción auto-renovable nuestra, vigente y no revocada.
    private static func hasActiveSubscription() async -> Bool {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            guard txn.productType == .autoRenewable,
                  subscriptionProductIDs.contains(txn.productID),
                  txn.revocationDate == nil else { continue }
            if let expiration = txn.expirationDate {
                if expiration > Date() { return true }
            } else {
                return true
            }
        }
        return false
    }
}
