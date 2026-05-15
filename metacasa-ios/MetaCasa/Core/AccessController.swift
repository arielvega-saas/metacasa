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

    /// Re-evalúa acceso: suscripción activa O trial vigente.
    func refresh() async {
        let subscribed = await Self.hasActiveSubscription()
        let inTrial = await TrialManager.isInTrial()
        let days = await TrialManager.daysRemaining()

        isSubscribed = subscribed
        isInTrial = inTrial
        trialDaysRemaining = days

        if subscribed || inTrial {
            state = .granted
        } else {
            state = .locked
        }
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
