import Foundation
import SwiftUI

struct RecurringTransaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var userId: UUID
    var type: TxType
    var amount: Decimal
    var category: String
    var subcategory: String?
    var account: String?
    var startDate: Date
    var endDate: Date?
    var nextDate: Date?
    var note: String?
    var frequency: Frequency
    var active: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case userId = "user_id"
        case type
        case amount
        case category
        case subcategory
        case account
        case startDate = "start_date"
        case endDate = "end_date"
        case nextDate = "next_date"
        case note
        case frequency
        case active
        case createdAt = "created_at"
    }
}

enum Frequency: String, Codable, Hashable, Sendable, CaseIterable {
    case daily, weekly, monthly, yearly

    /// LocalizedStringKey para usar directamente en Text en SwiftUI.
    var labelKey: LocalizedStringKey {
        switch self {
        case .daily: "freq.daily"
        case .weekly: "freq.weekly"
        case .monthly: "freq.monthly"
        case .yearly: "freq.yearly"
        }
    }

    var label: String {
        switch self {
        case .daily: String(localized: "freq.daily")
        case .weekly: String(localized: "freq.weekly")
        case .monthly: String(localized: "freq.monthly")
        case .yearly: String(localized: "freq.yearly")
        }
    }

    var systemIcon: String {
        switch self {
        case .daily: "calendar"
        case .weekly: "calendar.day.timeline.left"
        case .monthly: "calendar.badge.clock"
        case .yearly: "calendar.circle.fill"
        }
    }

    func nextDate(from date: Date) -> Date? {
        let cal = Calendar.current
        switch self {
        case .daily:   return cal.date(byAdding: .day,   value: 1,  to: date)
        case .weekly:  return cal.date(byAdding: .day,   value: 7,  to: date)
        case .monthly: return cal.date(byAdding: .month, value: 1,  to: date)
        case .yearly:  return cal.date(byAdding: .year,  value: 1,  to: date)
        }
    }
}
