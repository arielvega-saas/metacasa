import Foundation

struct Account: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var name: String
    var type: AccountType
    var currency: String
    var startingBalance: Decimal
    var institution: String?
    var accountNumberLast4: String?
    var icon: String?
    var color: String?
    var displayOrder: Int
    var isActive: Bool
    var notes: String?
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case type
        case currency
        case startingBalance = "starting_balance"
        case institution
        case accountNumberLast4 = "account_number_last4"
        case icon
        case color
        case displayOrder = "display_order"
        case isActive = "is_active"
        case notes
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum AccountType: String, Codable, Hashable, Sendable, CaseIterable {
    case checking, savings, cash
    case creditCard = "credit_card"
    case investment, loan, other

    var label: String {
        switch self {
        case .checking: "Cuenta corriente"
        case .savings: "Ahorro"
        case .cash: "Efectivo"
        case .creditCard: "Tarjeta de crédito"
        case .investment: "Inversión"
        case .loan: "Préstamo"
        case .other: "Otra"
        }
    }

    var systemIcon: String {
        switch self {
        case .checking: "banknote"
        case .savings: "building.columns"
        case .cash: "dollarsign.circle.fill"
        case .creditCard: "creditcard.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        case .loan: "arrow.down.circle"
        case .other: "circle"
        }
    }
}

/// Extensión 1:1 con `public.credit_cards` para cuentas type=creditCard.
struct CreditCardDetails: Codable, Hashable, Sendable {
    var accountId: UUID
    var creditLimit: Decimal
    var statementDay: Int
    var dueDay: Int
    var interestRateMonthly: Decimal
    var minimumPaymentPct: Decimal
    var lastStatementAmount: Decimal?
    var lastStatementDate: Date?
    var network: CardNetwork?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case creditLimit = "credit_limit"
        case statementDay = "statement_day"
        case dueDay = "due_day"
        case interestRateMonthly = "interest_rate_monthly"
        case minimumPaymentPct = "minimum_payment_pct"
        case lastStatementAmount = "last_statement_amount"
        case lastStatementDate = "last_statement_date"
        case network
    }
}

enum CardNetwork: String, Codable, Hashable, Sendable {
    case visa, mastercard, amex, discover, other
}
