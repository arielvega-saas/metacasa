import Foundation
import Supabase

/// Consulta el cache local `public.user_entitlements` (que escribe el webhook de RevenueCat).
actor EntitlementService {
    static let shared = EntitlementService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    func fetchAll() async throws -> [UserEntitlement] {
        try await client
            .from("user_entitlements")
            .select()
            .execute()
            .value
    }

    /// Consulta directa via helper SQL `public.has_active_entitlement(ent text)`.
    /// El SQL aplica la logica de expiración, así que no tenemos que replicarla en cliente.
    func hasActive(_ entitlement: String) async throws -> Bool {
        struct Params: Encodable { let ent: String }
        let value: Bool = try await client
            .rpc("has_active_entitlement", params: Params(ent: entitlement))
            .execute()
            .value
        return value
    }
}
