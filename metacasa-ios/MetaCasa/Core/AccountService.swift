import Foundation

actor AccountService {
    static let shared = AccountService()
    private init() {}

    func fetchAll(householdId: UUID, includingInactive: Bool = false) async throws -> [Account] {
        var q = PgQuery().eq("household_id", householdId)
        if !includingInactive {
            q = q.eq("is_active", true)
        }
        q = q.order("display_order")
        return try await SupabaseRPC.select(from: "accounts", query: q)
    }

    func create(
        userId: UUID,
        householdId: UUID,
        name: String,
        type: AccountType,
        currency: String,
        startingBalance: Decimal = 0,
        institution: String? = nil,
        icon: String? = nil,
        color: String? = nil
    ) async throws -> Account {
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
        return try await SupabaseRPC.insert(into: "accounts", payload: payload)
    }

    func update(_ account: Account) async throws -> Account {
        struct Patch: Encodable {
            let name: String
            let type: String
            let currency: String
            let starting_balance: Decimal
            let institution: String?
            let icon: String?
            let color: String?
            let display_order: Int
            let is_active: Bool
            let notes: String?
        }
        let patch = Patch(
            name: account.name,
            type: account.type.rawValue,
            currency: account.currency,
            starting_balance: account.startingBalance,
            institution: account.institution,
            icon: account.icon,
            color: account.color,
            display_order: account.displayOrder,
            is_active: account.isActive,
            notes: account.notes
        )
        return try await SupabaseRPC.update(
            table: "accounts",
            payload: patch,
            query: PgQuery().eq("id", account.id)
        )
    }

    func archive(id: UUID) async throws {
        struct Patch: Encodable { let is_active: Bool }
        try await SupabaseRPC.updateVoid(
            table: "accounts",
            payload: Patch(is_active: false),
            query: PgQuery().eq("id", id)
        )
    }

    /// Actualiza el ownership (personal/shared/external) y opcionalmente el user
    /// propietario. Usado para configurar waterfall multi-persona.
    func updateOwnership(id: UUID, ownership: AccountOwnership, ownerUserId: UUID? = nil) async throws {
        struct Patch: Encodable {
            let ownership: String
            let owner_user_id: UUID?
        }
        try await SupabaseRPC.updateVoid(
            table: "accounts",
            payload: Patch(ownership: ownership.rawValue, owner_user_id: ownerUserId),
            query: PgQuery().eq("id", id)
        )
    }
}
