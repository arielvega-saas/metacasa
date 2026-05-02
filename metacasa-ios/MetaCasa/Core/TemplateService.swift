import Foundation

actor TemplateService {
    static let shared = TemplateService()
    private init() {}

    func fetchAll(householdId: UUID) async throws -> [TransactionTemplate] {
        try await SupabaseRPC.select(
            from: "transaction_templates",
            query: PgQuery()
                .eq("household_id", householdId)
                .order("position", ascending: true)
        )
    }

    func create(
        userId: UUID,
        householdId: UUID,
        name: String,
        emoji: String? = nil,
        type: TxType,
        amount: Decimal,
        currency: String,
        category: String,
        subcategory: String? = nil,
        note: String? = nil,
        position: Int
    ) async throws -> TransactionTemplate {
        struct Payload: Encodable {
            let household_id: UUID
            let name: String
            let emoji: String?
            let type: String
            let amount: Decimal
            let currency: String
            let category: String
            let subcategory: String?
            let note: String?
            let position: Int
            let created_by: UUID
        }
        return try await SupabaseRPC.insert(
            into: "transaction_templates",
            payload: Payload(
                household_id: householdId,
                name: name,
                emoji: emoji,
                type: type.rawValue,
                amount: amount,
                currency: currency,
                category: category,
                subcategory: subcategory,
                note: note,
                position: position,
                created_by: userId
            )
        )
    }

    func delete(id: UUID) async throws {
        try await SupabaseRPC.delete(
            from: "transaction_templates",
            query: PgQuery().eq("id", id)
        )
    }

    func updatePosition(id: UUID, position: Int) async throws {
        struct Patch: Encodable { let position: Int }
        try await SupabaseRPC.updateVoid(
            table: "transaction_templates",
            payload: Patch(position: position),
            query: PgQuery().eq("id", id)
        )
    }
}
