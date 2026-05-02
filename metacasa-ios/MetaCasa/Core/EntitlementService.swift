import Foundation

/// Consulta el cache local `public.user_entitlements` (que escribe el webhook de RevenueCat).
actor EntitlementService {
    static let shared = EntitlementService()
    private init() {}

    func fetchAll() async throws -> [UserEntitlement] {
        try await SupabaseRPC.select(from: "user_entitlements")
    }

    /// Consulta directa via helper SQL `public.has_active_entitlement(ent text)`.
    /// El SQL aplica la logica de expiración, así que no tenemos que replicarla en cliente.
    func hasActive(_ entitlement: String) async throws -> Bool {
        struct Params: Encodable { let ent: String }
        return try await SupabaseRPC.call(
            "has_active_entitlement",
            params: Params(ent: entitlement)
        )
    }
}
