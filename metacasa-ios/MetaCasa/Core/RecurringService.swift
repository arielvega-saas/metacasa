import Foundation
import Supabase

actor RecurringService {
    static let shared = RecurringService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    func fetchAll(householdId: UUID, includeInactive: Bool = false) async throws -> [RecurringTransaction] {
        var q = client
            .from("recurring_transactions")
            .select()
            .eq("household_id", value: householdId)

        if !includeInactive {
            q = q.eq("active", value: true)
        }

        return try await q
            .order("next_date", ascending: true)
            .execute()
            .value
    }

    func create(householdId: UUID, type: TxType, amount: Decimal, category: String, frequency: Frequency, startDate: Date, endDate: Date? = nil, note: String? = nil) async throws -> RecurringTransaction {
        let userId = try await client.auth.session.user.id
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
        return try await client
            .from("recurring_transactions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func deactivate(id: UUID) async throws {
        struct Patch: Encodable { let active: Bool }
        try await client
            .from("recurring_transactions")
            .update(Patch(active: false))
            .eq("id", value: id)
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client
            .from("recurring_transactions")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
