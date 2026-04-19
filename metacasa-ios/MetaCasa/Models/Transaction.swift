import Foundation

struct Transaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var userId: UUID
    var accountId: UUID?
    var type: TxType
    var amount: Decimal
    var amountOriginal: Decimal?
    var currencyOriginal: String?
    var fxRateToBase: Decimal?
    var fxSource: String?
    var fxStatus: String?
    var category: String
    var subcategory: String?
    var account: String?
    var note: String?
    var date: Date
    var periodYear: Int?
    var periodMonth: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case userId = "user_id"
        case accountId = "account_id"
        case type
        case amount
        case amountOriginal = "amount_original"
        case currencyOriginal = "currency_original"
        case fxRateToBase = "fx_rate_to_base"
        case fxSource = "fx_source"
        case fxStatus = "fx_status"
        case category
        case subcategory
        case account
        case note
        case date
        case periodYear = "period_year"
        case periodMonth = "period_month"
        case createdAt = "created_at"
    }
}

enum TxType: String, Codable, Hashable, Sendable, CaseIterable {
    case gasto = "GASTO"
    case ingreso = "INGRESO"

    var label: String {
        switch self {
        case .gasto: "Gasto"
        case .ingreso: "Ingreso"
        }
    }

    var systemIcon: String {
        switch self {
        case .gasto: "arrow.down.circle.fill"
        case .ingreso: "arrow.up.circle.fill"
        }
    }
}

/// Payload para insertar una tx nueva. Supabase completará id/created_at.
struct NewTransactionInput: Codable, Sendable {
    var householdId: UUID
    var userId: UUID
    var accountId: UUID?
    var type: TxType
    var amount: Decimal
    var currencyOriginal: String?
    var category: String
    var subcategory: String?
    var note: String?
    var date: Date

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case userId = "user_id"
        case accountId = "account_id"
        case type
        case amount
        case currencyOriginal = "currency_original"
        case category
        case subcategory
        case note
        case date
    }
}
