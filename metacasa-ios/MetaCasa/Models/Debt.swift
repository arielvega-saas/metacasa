import Foundation

/// Deuda (préstamo, crédito). Port de `DebtForm` / `DebtCard` del web
/// (App.jsx:1648-1732).
struct Debt: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var creditor: String
    var originalAmount: Decimal
    var currentBalance: Decimal
    /// Tasa de interés **anual** en porcentaje (ej. 45.5 = 45.5%).
    var annualRate: Decimal
    /// Pago mensual sugerido (si está definido).
    var monthlyPayment: Decimal?
    var currency: String
    var startDate: Date
    var maturityDate: Date?
    var category: String?
    var note: String?
    var status: DebtStatus
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case creditor
        case originalAmount = "original_amount"
        case currentBalance = "current_balance"
        case annualRate = "annual_rate"
        case monthlyPayment = "monthly_payment"
        case currency
        case startDate = "start_date"
        case maturityDate = "maturity_date"
        case category
        case note
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Progreso pagado (0.0 – 1.0).
    var progress: Double {
        guard originalAmount > 0 else { return 0 }
        let paid = originalAmount - currentBalance
        let ratio = (paid as NSDecimalNumber).doubleValue / (originalAmount as NSDecimalNumber).doubleValue
        return min(max(0, ratio), 1)
    }

    /// Interés mensual estimado sobre el saldo actual (tasa anual / 12).
    var estimatedMonthlyInterest: Decimal {
        currentBalance * annualRate / 100 / 12
    }

    /// Proyección de meses hasta saldo cero asumiendo `monthlyPayment` constante
    /// y aplicando interés mensual. Aproximación simple (no considera frecuencia
    /// diaria, solo mensual).
    var estimatedMonthsToPayoff: Int? {
        guard let pay = monthlyPayment, pay > 0 else { return nil }
        var balance = currentBalance
        let monthlyRate = annualRate / 100 / 12
        var months = 0
        while balance > 0 && months < 600 {
            let interest = balance * monthlyRate
            balance += interest - pay
            months += 1
            if balance >= currentBalance && interest >= pay {
                // Pago no cubre el interés — nunca termina.
                return nil
            }
        }
        return months < 600 ? months : nil
    }

    /// Días restantes hasta la fecha de vencimiento.
    var daysUntilMaturity: Int? {
        guard let due = maturityDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: Date(), to: due).day
    }
}

enum DebtStatus: String, Codable, Hashable, Sendable {
    case active, settled
}
