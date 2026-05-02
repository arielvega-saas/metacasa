import Foundation

/// Plantilla de transacción guardada por el usuario para crear movimientos
/// recurrentes con 1 tap. Port del feature "quick shortcuts" del web
/// (App.jsx:3229-3244).
struct TransactionTemplate: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var name: String
    var emoji: String?
    var type: TxType
    var amount: Decimal
    var currency: String
    var category: String
    var subcategory: String?
    var note: String?
    var position: Int
    let createdBy: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case emoji
        case type
        case amount
        case currency
        case category
        case subcategory
        case note
        case position
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
