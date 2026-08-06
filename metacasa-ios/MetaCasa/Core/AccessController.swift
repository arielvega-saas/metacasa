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
/// Hay **tres** vías de acceso y cualquiera alcanza:
///
/// 1. Trial vigente — local, sin red.
/// 2. StoreKit 2 (`Transaction.currentEntitlements`) — la compra hecha en este Apple ID.
/// 3. `user_entitlements` en el servidor — la compra hecha en cualquier otro lado.
///
/// La 2 va antes que la 3 porque es local e instantánea. La 3 existe porque StoreKit
/// **sólo** conoce lo comprado en ese Apple ID: sin ella, quien paga desde la web o
/// desde Android queda bloqueado en iOS. RevenueCat no participa de la decisión — sólo
/// maneja la UI de compra en el paywall y alimenta la tabla vía webhook server-side.
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

        if subscribed {
            state = .granted
            return
        }

        // StoreKit sólo conoce las compras hechas EN ESTE Apple ID. Una suscripción
        // comprada desde la web o desde Android no está ahí, y hasta este arreglo la app
        // la bloqueaba igual: cobrábamos y no dábamos acceso, que es el peor final posible
        // y el mismo patrón que ya costó una vez con el doble-grant del paywall.
        //
        // El respaldo es `user_entitlements`, que escribe el webhook server-side de
        // RevenueCat y se lee por el RPC `has_active_entitlement` (con RLS: el cliente no
        // puede falsearla). Va SEGUNDO a propósito: StoreKit es local, instantáneo y
        // funciona sin red, así que el 99% de los casos se resuelve antes de llegar acá.
        //
        // Si ninguna de las dos contesta, `locked` y al paywall — que tiene reintento.
        // Ante la duda no se regala acceso.
        let serverEntitled = await Self.hasServerEntitlementBounded()
        isSubscribed = serverEntitled
        state = Self.decide(inTrial: false, storeKitSubscribed: false, serverEntitled: serverEntitled)
    }

    /// Consulta el entitlement del servidor con el mismo tope de tiempo que StoreKit.
    /// Devuelve `false` si no contesta: sin respuesta no hay acceso.
    private static func hasServerEntitlementBounded() async -> Bool {
        let resultado: Bool? = await withTimeout(storeKitTimeout) {
            (try? await EntitlementService.shared.hasActive(UserEntitlement.Name.premium)) ?? false
        }
        return resultado ?? false
    }

    /// La regla de acceso, aislada de StoreKit y de la red para poder testearla.
    ///
    /// Cualquiera de las tres vías abre la app; ninguna es capaz de cerrarla por su cuenta.
    /// Que sea un OR es el punto: el usuario pagó una vez, no importa por qué canal.
    static func decide(inTrial: Bool, storeKitSubscribed: Bool, serverEntitled: Bool) -> State {
        (inTrial || storeKitSubscribed || serverEntitled) ? .granted : .locked
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
