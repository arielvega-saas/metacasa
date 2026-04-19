import Foundation
import Supabase

actor AccountService {
    static let shared = AccountService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    func fetchAll(householdId: UUID, includingInactive: Bool = false) async throws -> [Account] {
        var query = client
            .from("accounts")
            .select()
            .eq("household_id", value: householdId)

        if !includingInactive {
            query = query.eq("is_active", value: true)
        }

        return try await query
            .order("display_order")
            .execute()
            .value
    }

    func create(householdId: UUID, name: String, type: AccountType, currency: String, startingBalance: Decimal = 0, institution: String? = nil, icon: String? = nil, color: String? = nil) async throws -> Account {
        let userId = try await client.auth.session.user.id
        struct Payload: Encodable {
            let household_id: UUID
            let name: String
            let type: String
            let currency: String
            let starting_balance: Decimal
            let institution: String?
            let icon: String?
            let color: String?
            let created_by: UUID
        }
        let payload = Payload(
            household_id: householdId,
            name: name,
            type: type.rawValue,
            currency: currency,
            starting_balance: startingBalance,
            institution: institution,
            icon: icon,
            color: color,
            created_by: userId
        )
        return try await client
            .from("accounts")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func update(_ account: Account) async throws -> Account {
        try await client
            .from("accounts")
            .update(account)
            .eq("id", value: account.id)
            .select()
            .single()
            .execute()
            .value
    }

    func archive(id: UUID) async throws {
        struct Patch: Encodable { let is_active: Bool }
        try await client
            .from("accounts")
            .update(Patch(is_active: false))
            .eq("id", value: id)
            .execute()
    }
}
