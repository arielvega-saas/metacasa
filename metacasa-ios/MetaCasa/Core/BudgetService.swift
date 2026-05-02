import Foundation

actor BudgetService {
    static let shared = BudgetService()
    private init() {}

    func fetchPeriod(householdId: UUID, containing date: Date) async throws -> BudgetPeriod? {
        try await SupabaseRPC.selectFirst(
            from: "budget_periods",
            query: PgQuery()
                .eq("household_id", householdId)
                .lte("period_start", date)
                .gte("period_end", date)
                .order("period_start", ascending: false)
        )
    }

    func fetchAllocations(periodId: UUID) async throws -> [BudgetAllocation] {
        try await SupabaseRPC.select(
            from: "budget_allocations",
            query: PgQuery().eq("period_id", periodId)
        )
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
        return try await SupabaseRPC.insert(into: "budget_periods", payload: payload)
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
        return try await SupabaseRPC.upsert(
            into: "budget_allocations",
            payload: payload,
            onConflict: "period_id,category,subcategory"
        )
    }

    /// Saldo del envelope vía la función SQL `public.envelope_balance(p_period_id, p_category, p_subcategory)`.
    func envelopeBalance(periodId: UUID, category: String, subcategory: String = "") async throws -> Decimal {
        struct Params: Encodable {
            let p_period_id: UUID
            let p_category: String
            let p_subcategory: String
        }
        return try await SupabaseRPC.call(
            "envelope_balance",
            params: Params(p_period_id: periodId, p_category: category, p_subcategory: subcategory)
        )
    }

    /// Actualiza el rollover_mode del envelope (none/surplus/full).
    func updateRolloverMode(allocationId: UUID, mode: RolloverMode) async throws {
        struct Patch: Encodable { let rollover_mode: String }
        try await SupabaseRPC.updateVoid(
            table: "budget_allocations",
            payload: Patch(rollover_mode: mode.rawValue),
            query: PgQuery().eq("id", allocationId)
        )
    }

    /// Elimina un envelope del período.
    func deleteAllocation(id: UUID) async throws {
        try await SupabaseRPC.delete(
            from: "budget_allocations",
            query: PgQuery().eq("id", id)
        )
    }

    /// Trae un period específico por mes (ensure, pero para cualquier mes).
    func ensurePeriodForMonth(householdId: UUID, containing date: Date) async throws -> BudgetPeriod {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            throw NSError(domain: "BudgetService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fecha inválida"])
        }
        if let existing = try? await fetchPeriod(householdId: householdId, containing: date) {
            return existing
        }
        struct Payload: Encodable {
            let household_id: UUID
            let period_type: String
            let period_start: Date
            let period_end: Date
        }
        return try await SupabaseRPC.insert(
            into: "budget_periods",
            payload: Payload(
                household_id: householdId,
                period_type: "month",
                period_start: start,
                period_end: end
            )
        )
    }
}
