import Foundation
import Supabase

actor TransactionService {
    static let shared = TransactionService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    func fetchForPeriod(householdId: UUID, from: Date, to: Date, limit: Int = 200) async throws -> [Transaction] {
        try await client
            .from("transactions")
            .select()
            .eq("household_id", value: householdId)
            .gte("date", value: from)
            .lte("date", value: to)
            .order("date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func insert(_ input: NewTransactionInput) async throws -> Transaction {
        try await client
            .from("transactions")
            .insert(input)
            .select()
            .single()
            .execute()
            .value
    }

    func delete(id: UUID) async throws {
        try await client
            .from("transactions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func update(_ transaction: Transaction) async throws -> Transaction {
        try await client
            .from("transactions")
            .update(transaction)
            .eq("id", value: transaction.id)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchOne(id: UUID) async throws -> Transaction? {
        let rows: [Transaction] = try await client
            .from("transactions")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func totals(householdId: UUID, from: Date, to: Date) async throws -> (ingresos: Decimal, gastos: Decimal) {
        let txs = try await fetchForPeriod(householdId: householdId, from: from, to: to, limit: 1000)
        let ing = txs.filter { $0.type == .ingreso }.reduce(Decimal(0)) { $0 + $1.amount }
        let gast = txs.filter { $0.type == .gasto }.reduce(Decimal(0)) { $0 + $1.amount }
        return (ing, gast)
    }
}
