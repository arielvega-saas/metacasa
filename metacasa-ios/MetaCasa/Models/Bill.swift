import Foundation

/// Vencimiento (bill) — una obligación de pago con fecha específica.
/// Port de `BillForm` / `BillCard` del web (App.jsx:653-800).
struct Bill: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var title: String
    var description: String?
    var amount: Decimal
    var currency: String
    var dueDate: Date
    var status: BillStatus
    var paidAt: Date?
    var category: String?
    var accountId: UUID?
    var note: String?
    var recurring: Bool
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case title
        case description
        case amount
        case currency
        case dueDate = "due_date"
        case status
        case paidAt = "paid_at"
        case category
        case accountId = "account_id"
        case note
        case recurring
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Estado visual según `dueDate` y `status`.
    /// Refleja los colores del web (App.jsx:5706-5724).
    enum UrgencyLevel {
        case paid
        case overdue        // pasada, no pagada
        case dueToday       // hoy
        case dueSoon        // 1-3 días
        case upcoming       // 4-14 días
        case future         // >14 días
        case skipped
    }

    var urgency: UrgencyLevel {
        if status == .paid { return .paid }
        if status == .skipped { return .skipped }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let due = cal.startOfDay(for: dueDate)
        let days = cal.dateComponents([.day], from: today, to: due).day ?? 0
        if days < 0 { return .overdue }
        if days == 0 { return .dueToday }
        if days <= 3 { return .dueSoon }
        if days <= 14 { return .upcoming }
        return .future
    }

    var daysUntilDue: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let due = cal.startOfDay(for: dueDate)
        return cal.dateComponents([.day], from: today, to: due).day ?? 0
    }
}

enum BillStatus: String, Codable, Hashable, Sendable {
    case pending, paid, skipped
    var label: String {
        switch self {
        case .pending: return "Pendiente"
        case .paid:    return "Pagado"
        case .skipped: return "Saltado"
        }
    }
}
