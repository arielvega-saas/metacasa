import Foundation

actor GoalService {
    static let shared = GoalService()
    private init() {}

    func fetchAll(householdId: UUID, includeCompleted: Bool = true) async throws -> [Goal] {
        var q = PgQuery().eq("household_id", householdId)
        if !includeCompleted {
            q = q.neq("status", "completed")
        }
        q = q.order("priority", ascending: false).order("created_at", ascending: true)
        return try await SupabaseRPC.select(from: "goals", query: q)
    }

    func create(
        userId: UUID,
        householdId: UUID,
        name: String,
        targetAmount: Decimal,
        currency: String,
        targetDate: Date? = nil,
        icon: String? = nil,
        color: String? = nil,
        priority: Int = 0,
        category: String? = nil
    ) async throws -> Goal {
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
        return try await SupabaseRPC.insert(into: "goals", payload: payload)
    }

    func update(_ goal: Goal) async throws -> Goal {
        struct Patch: Encodable {
            let name: String
            let description: String?
            let target_amount: Decimal
            let currency: String
            let target_date: Date?
            let status: String
            let icon: String?
            let color: String?
            let priority: Int
            let category: String?
            let account_id: UUID?
            let notes: String?
        }
        let patch = Patch(
            name: goal.name,
            description: goal.description,
            target_amount: goal.targetAmount,
            currency: goal.currency,
            target_date: goal.targetDate,
            status: goal.status.rawValue,
            icon: goal.icon,
            color: goal.color,
            priority: goal.priority,
            category: goal.category,
            account_id: goal.accountId,
            notes: goal.notes
        )
        return try await SupabaseRPC.update(
            table: "goals",
            payload: patch,
            query: PgQuery().eq("id", goal.id)
        )
    }

    func delete(id: UUID) async throws {
        try await SupabaseRPC.delete(
            from: "goals",
            query: PgQuery().eq("id", id)
        )
    }

    func contribute(userId: UUID, goalId: UUID, amount: Decimal, notes: String? = nil) async throws -> GoalContribution {
        struct Payload: Encodable {
            let goal_id: UUID
            let amount: Decimal
            let contributed_by: UUID
            let notes: String?
        }
        return try await SupabaseRPC.insert(
            into: "goal_contributions",
            payload: Payload(goal_id: goalId, amount: amount, contributed_by: userId, notes: notes)
        )
    }

    func fetchContributions(goalId: UUID) async throws -> [GoalContribution] {
        try await SupabaseRPC.select(
            from: "goal_contributions",
            query: PgQuery().eq("goal_id", goalId).order("contributed_at", ascending: false)
        )
    }

    func removeContribution(id: UUID) async throws {
        try await SupabaseRPC.delete(
            from: "goal_contributions",
            query: PgQuery().eq("id", id)
        )
    }
}
