import Foundation
import Supabase

actor BudgetService {
    static let shared = BudgetService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    func fetchPeriod(householdId: UUID, containing date: Date) async throws -> BudgetPeriod? {
        let periods: [BudgetPeriod] = try await client
            .from("budget_periods")
            .select()
            .eq("household_id", value: householdId)
            .lte("period_start", value: date)
            .gte("period_end", value: date)
            .order("period_start", ascending: false)
            .limit(1)
            .execute()
            .value
        return periods.first
    }

    func fetchAllocations(periodId: UUID) async throws -> [BudgetAllocation] {
        try await client
            .from("budget_allocations")
            .select()
            .eq("period_id", value: periodId)
            .execute()
            .value
    }

    /// Si no existe period para el mes actual, crea uno. Devuelve siempre un period válido.
    func ensurePeriodForCurrentMonth(householdId: UUID) async throws -> BudgetPeriod {
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            throw NSError(domain: "BudgetService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fecha inválida"])
        }

        if let existing = try? await fetchPeriod(householdId: householdId, containing: now) {
            return existing
        }

        struct Payload: Encodable {
            let household_id: UUID
            let period_type: String
            let period_start: Date
            let period_end: Date
        }
        let payload = Payload(
            household_id: householdId,
            period_type: "month",
            period_start: start,
            period_end: end
        )
        return try await client
            .from("budget_periods")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func upsertAllocation(periodId: UUID, category: String, subcategory: String = "", allocated: Decimal, currency: String = "USD") async throws -> BudgetAllocation {
        struct Payload: Encodable {
            let period_id: UUID
            let category: String
            let subcategory: String
            let allocated: Decimal
            let currency: String
        }
        let payload = Payload(
            period_id: periodId,
            category: category,
            subcategory: subcategory,
            allocated: allocated,
            currency: currency
        )
        return try await client
            .from("budget_allocations")
            .upsert(payload, onConflict: "period_id,category,subcategory")
            .select()
            .single()
            .execute()
            .value
    }

    /// Saldo del envelope vía la función SQL `public.envelope_balance(p_period_id, p_category, p_subcategory)`.
    func envelopeBalance(periodId: UUID, category: String, subcategory: String = "") async throws -> Decimal {
        struct Params: Encodable {
            let p_period_id: UUID
            let p_category: String
            let p_subcategory: String
        }
        let params = Params(p_period_id: periodId, p_category: category, p_subcategory: subcategory)
        let value: Decimal = try await client
            .rpc("envelope_balance", params: params)
            .execute()
            .value
        return value
    }
}
