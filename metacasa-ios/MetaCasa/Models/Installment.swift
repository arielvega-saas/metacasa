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

    /// Cuota mensual "de catálogo", redondeada a 2 decimales.
    ///
    /// Es lo que se muestra para las cuotas 1..n−1. La última la ajusta `amount(forInstallment:)`
    /// para absorber el residuo.
    var monthlyAmount: Decimal {
        guard totalInstallments > 0 else { return 0 }
        return Self.roundedToCents(totalAmount / Decimal(totalInstallments))
    }

    /// Monto de la cuota `n` (1-indexed), con el residuo absorbido en la última.
    ///
    /// Sin esto, un plan de $1.000.000 en 12 daba doce cuotas de `83333,333…` que la UI mostraba
    /// como $83.333 — y 12 × $83.333 = **$999.996**. Faltaban $4 que no estaban en ninguna cuota,
    /// y el usuario que suma sus cuotas no llega al total de su plan. Cualquier tarjeta factura al
    /// revés: n−1 cuotas parejas y la última cierra la diferencia exacta.
    func amount(forInstallment n: Int) -> Decimal {
        guard totalInstallments > 0, n >= 1, n <= totalInstallments else { return 0 }
        let regular = monthlyAmount
        guard n == totalInstallments else { return regular }
        // La última cierra: total − lo ya facturado. Así la suma da SIEMPRE el total exacto.
        return totalAmount - regular * Decimal(totalInstallments - 1)
    }

    static func roundedToCents(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
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
