import Foundation

/// Plan de cuotas (ej. iPhone 15 en 12 cuotas).
/// Port de `CuotaForm` / `CuotaCard` del web (App.jsx:1221-1555).
struct InstallmentPlan: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var name: String
    var totalAmount: Decimal
    var totalInstallments: Int
    var currency: String
    var startYear: Int
    var startMonth: Int
    var category: String?
    var accountId: UUID?
    var note: String?
    var status: PlanStatus
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case totalAmount = "total_amount"
        case totalInstallments = "total_installments"
        case currency
        case startYear = "start_year"
        case startMonth = "start_month"
        case category
        case accountId = "account_id"
        case note
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var monthlyAmount: Decimal {
        guard totalInstallments > 0 else { return 0 }
        return totalAmount / Decimal(totalInstallments)
    }

    /// Fecha efectiva de la cuota número `n` (1-indexed).
    func periodFor(installment n: Int) -> (year: Int, month: Int) {
        let offset = n - 1
        var y = startYear
        var m = startMonth + offset
        while m > 12 { m -= 12; y += 1 }
        while m < 1  { m += 12; y -= 1 }
        return (y, m)
    }

    /// Indica si la cuota del (año, mes) dado corresponde a este plan.
    func installmentNumber(for year: Int, month: Int) -> Int? {
        let startMonths = startYear * 12 + (startMonth - 1)
        let targetMonths = year * 12 + (month - 1)
        let diff = targetMonths - startMonths
        guard diff >= 0, diff < totalInstallments else { return nil }
        return diff + 1
    }

    enum PlanStatus: String, Codable, Hashable, Sendable {
        case active, completed, cancelled
    }
}

/// Ledger mensual de cuota (una fila por mes planificado).
struct InstallmentPayment: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var planId: UUID
    var periodYear: Int
    var periodMonth: Int
    var installmentNumber: Int
    var amount: Decimal
    var paid: Bool
    var paidAt: Date?
    var transactionId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case periodYear = "period_year"
        case periodMonth = "period_month"
        case installmentNumber = "installment_number"
        case amount
        case paid
        case paidAt = "paid_at"
        case transactionId = "transaction_id"
    }
}
