import Foundation
import RevenueCat

/// Wrapper async sobre el SDK de RevenueCat. Mantiene la integración aislada del
/// resto de la app para poder testear el paywall con mocks en simulator.
///
/// Flujo esperado:
///   1. `configure()` en el bootstrap de la app.
///   2. `login(userId:)` cuando hay sesión de Supabase activa (hoy se hookea
///      desde `MetaCasaApp` via `.onChange(of: appState.currentUserId)`).
///   3. `currentOffering()` desde `PaywallView` para listar paquetes.
///   4. `purchase(package:)` al tap del CTA.
///   5. Webhook server-side de RevenueCat actualiza `public.user_entitlements`
///      en Supabase → `EntitlementService.hasActive(.premium)` refleja el cambio.
actor RevenueCatService {
    static let shared = RevenueCatService()
    private init() {}

    enum ServiceError: LocalizedError {
        case notConfigured
        case offeringsUnavailable
        case userCanceled

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "RevenueCat no está configurado. Agregá REVENUECAT_API_KEY al Info.plist."
            case .offeringsUnavailable:
                return "No hay planes disponibles en este momento. Intentá de nuevo en unos minutos."
            case .userCanceled:
                return "Compra cancelada."
            }
        }
    }

    private var isConfigured = false

    /// Inicializa el SDK. Idempotente — llamar varias veces es seguro.
    /// Si no hay API key en `Config.revenueCatAPIKey`, queda en modo placeholder.
    func configure() {
        guard !isConfigured else { return }
        guard let key = Config.revenueCatAPIKey else {
            print("[RevenueCat] API key missing in Info.plist (REVENUECAT_API_KEY). Paywall in placeholder mode.")
            return
        }
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: key)
        isConfigured = true
    }

    var configured: Bool { isConfigured }

    /// Vincula la cuenta de RevenueCat al user de Supabase para que el webhook
    /// pueda escribir en `user_entitlements` con el UUID correcto.
    func login(userId: UUID) async {
        guard isConfigured else { return }
        do {
            _ = try await Purchases.shared.logIn(userId.uuidString)
        } catch {
            print("[RevenueCat] logIn failed: \(error.localizedDescription)")
        }
    }

    func logout() async {
        guard isConfigured else { return }
        _ = try? await Purchases.shared.logOut()
    }

    /// Retorna el offering "current" configurado en el dashboard de RevenueCat
    /// (normalmente "default" con packages mensual y anual).
    func currentOffering() async throws -> Offering {
        guard isConfigured else { throw ServiceError.notConfigured }
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else {
            throw ServiceError.offeringsUnavailable
        }
        return current
    }

    /// Ejecuta una compra. Lanza `.userCanceled` si el usuario cancela en el
    /// sheet de Apple. Devuelve true si el entitlement premium quedó activo.
    @discardableResult
    func purchase(package: Package) async throws -> Bool {
        guard isConfigured else { throw ServiceError.notConfigured }
        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled { throw ServiceError.userCanceled }
        return result.customerInfo.entitlements[UserEntitlement.Name.premium]?.isActive == true
    }

    /// Restaura compras previas asociadas a la Apple ID actual.
    @discardableResult
    func restore() async throws -> Bool {
        guard isConfigured else { throw ServiceError.notConfigured }
        let info = try await Purchases.shared.restorePurchases()
        return info.entitlements[UserEntitlement.Name.premium]?.isActive == true
    }

    /// Lee el `CustomerInfo` actual desde cache local (si es reciente) o servidor.
    func currentCustomerInfo() async throws -> CustomerInfo {
        guard isConfigured else { throw ServiceError.notConfigured }
        return try await Purchases.shared.customerInfo()
    }
}
