import Foundation

struct BudgetPeriod: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var periodType: PeriodType
    var periodStart: Date
    var periodEnd: Date
    var totalIncome: Decimal
    var totalAllocated: Decimal
    var readyToAssign: Decimal
    var notes: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case periodType = "period_type"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case totalIncome = "total_income"
        case totalAllocated = "total_allocated"
        case readyToAssign = "ready_to_assign"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum PeriodType: String, Codable, Hashable, Sendable, CaseIterable {
    case week, biweek, month, quarter, year, custom

    var label: String {
        switch self {
        case .week: "Semanal"
        case .biweek: "Quincenal"
        case .month: "Mensual"
        case .quarter: "Trimestral"
        case .year: "Anual"
        case .custom: "Personalizado"
        }
    }
}

struct BudgetAllocation: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var periodId: UUID
    var category: String
    var subcategory: String
    var allocated: Decimal
    var rolloverFromPrev: Decimal
    var rolloverMode: RolloverMode
    var currency: String
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case periodId = "period_id"
        case category
        case subcategory
        case allocated
        case rolloverFromPrev = "rollover_from_prev"
        case rolloverMode = "rollover_mode"
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum RolloverMode: String, Codable, Hashable, Sendable, CaseIterable {
    case none, surplus, full

    var label: String {
        switch self {
        case .none: "Sin rollover"
        case .surplus: "Solo sobrante"
        case .full: "Todo el saldo"
        }
    }
}

/// Cálculo ligero del saldo de un envelope en cliente.
/// La fuente canónica sigue siendo la función SQL `public.envelope_balance(...)`.
struct EnvelopeStatus: Hashable, Sendable {
    let category: String
    let subcategory: String
    let allocated: Decimal
    let spent: Decimal

    var remaining: Decimal { allocated - spent }
    var percentUsed: Double {
        guard allocated > 0 else { return 0 }
        return min(1, max(0, (spent as NSDecimalNumber).doubleValue / (allocated as NSDecimalNumber).doubleValue))
    }
    var isOverBudget: Bool { spent > allocated }
}
