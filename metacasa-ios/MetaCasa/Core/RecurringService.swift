import Foundation

actor RecurringService {
    static let shared = RecurringService()
    private init() {}

    func fetchAll(householdId: UUID, includeInactive: Bool = false) async throws -> [RecurringTransaction] {
        var q = PgQuery().eq("household_id", householdId)
        if !includeInactive {
            q = q.eq("active", true)
        }
        q = q.order("next_date", ascending: true)
        return try await SupabaseRPC.select(from: "recurring_transactions", query: q)
    }

    func create(
        userId: UUID,
        householdId: UUID,
        type: TxType,
        amount: Decimal,
        category: String,
        frequency: Frequency,
        startDate: Date,
        endDate: Date? = nil,
        note: String? = nil
    ) async throws -> RecurringTransaction {
        struct Payload: Encodable {
            let household_id: UUID
            let user_id: UUID
            let type: String
            let amount: Decimal
            let category: String
            let frequency: String
            let start_date: Date
            let end_date: Date?
            let next_date: Date?
            let note: String?
        }
        let payload = Payload(
            household_id: householdId,
            user_id: userId,
            type: type.rawValue,
            amount: amount,
            category: category,
            frequency: frequency.rawValue,
            start_date: startDate,
            end_date: endDate,
            next_date: startDate,
            note: note
        )
        return try await SupabaseRPC.insert(into: "recurring_transactions", payload: payload)
    }

    func deactivate(id: UUID) async throws {
        struct Patch: Encodable { let active: Bool }
        try await SupabaseRPC.updateVoid(
            table: "recurring_transactions",
            payload: Patch(active: false),
            query: PgQuery().eq("id", id)
        )
    }

    func delete(id: UUID) async throws {
        try await SupabaseRPC.delete(
            from: "recurring_transactions",
            query: PgQuery().eq("id", id)
        )
    }
}
