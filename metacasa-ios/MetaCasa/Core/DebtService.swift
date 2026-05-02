import Foundation

actor DebtService {
    static let shared = DebtService()
    private init() {}

    func fetchAll(householdId: UUID, includeSettled: Bool = true) async throws -> [Debt] {
        var q = PgQuery().eq("household_id", householdId)
        if !includeSettled {
            q = q.eq("status", "active")
        }
        q = q.order("created_at", ascending: false)
        return try await SupabaseRPC.select(from: "debts", query: q)
    }

    func create(
        userId: UUID,
        householdId: UUID,
        creditor: String,
        originalAmount: Decimal,
        currentBalance: Decimal,
        annualRate: Decimal,
        monthlyPayment: Decimal?,
        currency: String,
        startDate: Date,
        maturityDate: Date? = nil,
        category: String? = nil,
        note: String? = nil
    ) async throws -> Debt {
        struct Payload: Encodable {
            let household_id: UUID
            let creditor: String
            let original_amount: Decimal
            let current_balance: Decimal
            let annual_rate: Decimal
            let monthly_payment: Decimal?
            let currency: String
            let start_date: Date
            let maturity_date: Date?
            let category: String?
            let note: String?
            let created_by: UUID
        }
        return try await SupabaseRPC.insert(
            into: "debts",
            payload: Payload(
                household_id: householdId,
                creditor: creditor,
                original_amount: originalAmount,
                current_balance: currentBalance,
                annual_rate: annualRate,
                monthly_payment: monthlyPayment,
                currency: currency,
                start_date: startDate,
                maturity_date: maturityDate,
                category: category,
                note: note,
                created_by: userId
            )
        )
    }

    func update(_ debt: Debt) async throws -> Debt {
        struct Patch: Encodable {
            let creditor: String
            let current_balance: Decimal
            let annual_rate: Decimal
            let monthly_payment: Decimal?
            let maturity_date: Date?
            let category: String?
            let note: String?
            let status: String
        }
        return try await SupabaseRPC.update(
            table: "debts",
            payload: Patch(
                creditor: debt.creditor,
                current_balance: debt.currentBalance,
                annual_rate: debt.annualRate,
                monthly_payment: debt.monthlyPayment,
                maturity_date: debt.maturityDate,
                category: debt.category,
                note: debt.note,
                status: debt.status.rawValue
            ),
            query: PgQuery().eq("id", debt.id)
        )
    }

    func settle(id: UUID) async throws {
        struct Patch: Encodable {
            let status: String
            let current_balance: Decimal
        }
        try await SupabaseRPC.updateVoid(
            table: "debts",
            payload: Patch(status: "settled", current_balance: 0),
            query: PgQuery().eq("id", id)
        )
    }

    func delete(id: UUID) async throws {
        try await SupabaseRPC.delete(from: "debts", query: PgQuery().eq("id", id))
    }
}
