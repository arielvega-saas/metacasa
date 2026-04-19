import Foundation
import Supabase

actor GoalService {
    static let shared = GoalService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    func fetchAll(householdId: UUID, includeCompleted: Bool = true) async throws -> [Goal] {
        var query = client
            .from("goals")
            .select()
            .eq("household_id", value: householdId)

        if !includeCompleted {
            query = query.neq("status", value: "completed")
        }

        return try await query
            .order("priority", ascending: false)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func create(householdId: UUID, name: String, targetAmount: Decimal, currency: String, targetDate: Date? = nil, icon: String? = nil, color: String? = nil, priority: Int = 0, category: String? = nil) async throws -> Goal {
        let userId = try await client.auth.session.user.id
        struct Payload: Encodable {
            let household_id: UUID
            let name: String
            let target_amount: Decimal
            let currency: String
            let target_date: Date?
            let icon: String?
            let color: String?
            let priority: Int
            let category: String?
            let created_by: UUID
        }
        let payload = Payload(
            household_id: householdId,
            name: name,
            target_amount: targetAmount,
            currency: currency,
            target_date: targetDate,
            icon: icon,
            color: color,
            priority: priority,
            category: category,
            created_by: userId
        )
        return try await client
            .from("goals")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func update(_ goal: Goal) async throws -> Goal {
        try await client
            .from("goals")
            .update(goal)
            .eq("id", value: goal.id)
            .select()
            .single()
            .execute()
            .value
    }

    func delete(id: UUID) async throws {
        try await client
            .from("goals")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func contribute(goalId: UUID, amount: Decimal, notes: String? = nil) async throws -> GoalContribution {
        let userId = try await client.auth.session.user.id
        struct Payload: Encodable {
            let goal_id: UUID
            let amount: Decimal
            let contributed_by: UUID
            let notes: String?
        }
        return try await client
            .from("goal_contributions")
            .insert(Payload(goal_id: goalId, amount: amount, contributed_by: userId, notes: notes))
            .select()
            .single()
            .execute()
            .value
    }

    func fetchContributions(goalId: UUID) async throws -> [GoalContribution] {
        try await client
            .from("goal_contributions")
            .select()
            .eq("goal_id", value: goalId)
            .order("contributed_at", ascending: false)
            .execute()
            .value
    }

    func removeContribution(id: UUID) async throws {
        try await client
            .from("goal_contributions")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
