import Foundation

struct Goal: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var name: String
    var description: String?
    var targetAmount: Decimal
    var currentAmount: Decimal
    var currency: String
    var targetDate: Date?
    var status: GoalStatus
    var icon: String?
    var color: String?
    var priority: Int
    var category: String?
    var accountId: UUID?
    var notes: String?
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case description
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case currency
        case targetDate = "target_date"
        case status
        case icon
        case color
        case priority
        case category
        case accountId = "account_id"
        case notes
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, (currentAmount as NSDecimalNumber).doubleValue / (targetAmount as NSDecimalNumber).doubleValue)
    }
}

enum GoalStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case active, completed, paused, canceled

    var label: String {
        switch self {
        case .active: "Activa"
        case .completed: "Completada"
        case .paused: "Pausada"
        case .canceled: "Cancelada"
        }
    }
}

struct GoalContribution: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let goalId: UUID
    var amount: Decimal
    let contributedBy: UUID
    var contributedAt: Date
    var notes: String?
    var transactionId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case amount
        case contributedBy = "contributed_by"
        case contributedAt = "contributed_at"
        case notes
        case transactionId = "transaction_id"
    }
}
