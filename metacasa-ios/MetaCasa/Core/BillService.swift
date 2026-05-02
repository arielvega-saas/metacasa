import Foundation

actor BillService {
    static let shared = BillService()
    private init() {}

    func fetchAll(householdId: UUID, includeCompleted: Bool = true) async throws -> [Bill] {
        var q = PgQuery().eq("household_id", householdId)
        if !includeCompleted {
            q = q.neq("status", "paid")
        }
        q = q.order("due_date", ascending: true)
        return try await SupabaseRPC.select(from: "bills", query: q)
    }

    func fetchUpcoming(householdId: UUID, daysAhead: Int = 30) async throws -> [Bill] {
        let cal = Calendar.current
        let to = cal.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()
        let q = PgQuery()
            .eq("household_id", householdId)
            .eq("status", "pending")
            .lte("due_date", to)
            .order("due_date", ascending: true)
        return try await SupabaseRPC.select(from: "bills", query: q)
    }

    func fetchForMonth(householdId: UUID, year: Int, month: Int) async throws -> [Bill] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        var comps = DateComponents(); comps.year = year; comps.month = month
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            return []
        }
        let q = PgQuery()
            .eq("household_id", householdId)
            .gte("due_date", start)
            .lte("due_date", end)
            .order("due_date", ascending: true)
        return try await SupabaseRPC.select(from: "bills", query: q)
    }

    func create(
        userId: UUID,
        householdId: UUID,
        title: String,
        description: String? = nil,
        amount: Decimal,
        currency: String,
        dueDate: Date,
        category: String? = nil,
        accountId: UUID? = nil,
        note: String? = nil,
        recurring: Bool = false
    ) async throws -> Bill {
        struct Payload: Encodable {
            let household_id: UUID
            let title: String
            let description: String?
            let amount: Decimal
            let currency: String
            let due_date: Date
            let category: String?
            let account_id: UUID?
            let note: String?
            let recurring: Bool
            let created_by: UUID
        }
        return try await SupabaseRPC.insert(
            into: "bills",
            payload: Payload(
                household_id: householdId,
                title: title,
                description: description,
                amount: amount,
                currency: currency,
                due_date: dueDate,
                category: category,
                account_id: accountId,
                note: note,
                recurring: recurring,
                created_by: userId
            )
        )
    }

    func update(_ bill: Bill) async throws -> Bill {
        struct Patch: Encodable {
            let title: String
            let description: String?
            let amount: Decimal
            let currency: String
            let due_date: Date
            let status: String
            let paid_at: Date?
            let category: String?
            let account_id: UUID?
            let note: String?
            let recurring: Bool
        }
        let patch = Patch(
            title: bill.title,
            description: bill.description,
            amount: bill.amount,
            currency: bill.currency,
            due_date: bill.dueDate,
            status: bill.status.rawValue,
            paid_at: bill.paidAt,
            category: bill.category,
            account_id: bill.accountId,
            note: bill.note,
            recurring: bill.recurring
        )
        return try await SupabaseRPC.update(
            table: "bills",
            payload: patch,
            query: PgQuery().eq("id", bill.id)
        )
    }

    func markPaid(id: UUID) async throws {
        struct Patch: Encodable {
            let status: String
            let paid_at: String
        }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
        try await SupabaseRPC.updateVoid(
            table: "bills",
            payload: Patch(status: "paid", paid_at: iso.string(from: Date())),
            query: PgQuery().eq("id", id)
        )
    }

    func delete(id: UUID) async throws {
        try await SupabaseRPC.delete(from: "bills", query: PgQuery().eq("id", id))
    }
}
