import Foundation

actor InstallmentService {
    static let shared = InstallmentService()
    private init() {}

    // MARK: - Plans

    func fetchPlans(householdId: UUID, includeCompleted: Bool = true) async throws -> [InstallmentPlan] {
        var q = PgQuery().eq("household_id", householdId)
        if !includeCompleted {
            q = q.eq("status", "active")
        }
        q = q.order("created_at", ascending: false)
        return try await SupabaseRPC.select(from: "installment_plans", query: q)
    }

    func createPlan(
        userId: UUID,
        householdId: UUID,
        name: String,
        totalAmount: Decimal,
        totalInstallments: Int,
        currency: String,
        startYear: Int,
        startMonth: Int,
        category: String? = nil,
        accountId: UUID? = nil,
        note: String? = nil
    ) async throws -> InstallmentPlan {
        struct Payload: Encodable {
            let household_id: UUID
            let name: String
            let total_amount: Decimal
            let total_installments: Int
            let currency: String
            let start_year: Int
            let start_month: Int
            let category: String?
            let account_id: UUID?
            let note: String?
            let created_by: UUID
        }
        let plan: InstallmentPlan = try await SupabaseRPC.insert(
            into: "installment_plans",
            payload: Payload(
                household_id: householdId,
                name: name,
                total_amount: totalAmount,
                total_installments: totalInstallments,
                currency: currency,
                start_year: startYear,
                start_month: startMonth,
                category: category,
                account_id: accountId,
                note: note,
                created_by: userId
            )
        )
        // Crear ledger de pagos en background
        try await seedPayments(for: plan)
        return plan
    }

    /// Crea las filas de `installment_payments` para cada cuota del plan.
    private func seedPayments(for plan: InstallmentPlan) async throws {
        struct RowPayload: Encodable {
            let plan_id: UUID
            let period_year: Int
            let period_month: Int
            let installment_number: Int
            let amount: Decimal
        }
        for n in 1...plan.totalInstallments {
            let period = plan.periodFor(installment: n)
            do {
                try await SupabaseRPC.insertVoid(
                    into: "installment_payments",
                    payload: RowPayload(
                        plan_id: plan.id,
                        period_year: period.year,
                        period_month: period.month,
                        installment_number: n,
                        amount: plan.monthlyAmount
                    )
                )
            } catch {
                // Silenciamos duplicados (unique constraint). Otros errores se propagan.
            }
        }
    }

    func deletePlan(id: UUID) async throws {
        try await SupabaseRPC.delete(
            from: "installment_plans",
            query: PgQuery().eq("id", id)
        )
        // ON DELETE CASCADE borra los payments automáticamente.
    }

    func cancelPlan(id: UUID) async throws {
        struct Patch: Encodable { let status: String }
        try await SupabaseRPC.updateVoid(
            table: "installment_plans",
            payload: Patch(status: "cancelled"),
            query: PgQuery().eq("id", id)
        )
    }

    // MARK: - Payments

    func fetchPayments(planId: UUID) async throws -> [InstallmentPayment] {
        try await SupabaseRPC.select(
            from: "installment_payments",
            query: PgQuery()
                .eq("plan_id", planId)
                .order("installment_number", ascending: true)
        )
    }

    /// Trae todos los pagos PENDIENTES del hogar en el mes dado. Usado por el
    /// waterfall para calcular la deducción mensual de cuotas.
    func fetchPaymentsForMonth(
        householdId: UUID,
        year: Int,
        month: Int
    ) async throws -> [(plan: InstallmentPlan, payment: InstallmentPayment)] {
        // 1. Traer planes activos del hogar
        let plans: [InstallmentPlan] = try await SupabaseRPC.select(
            from: "installment_plans",
            query: PgQuery()
                .eq("household_id", householdId)
                .eq("status", "active")
        )
        var result: [(plan: InstallmentPlan, payment: InstallmentPayment)] = []
        for p in plans {
            let payments: [InstallmentPayment] = try await SupabaseRPC.select(
                from: "installment_payments",
                query: PgQuery()
                    .eq("plan_id", p.id)
                    .eq("period_year", year)
                    .eq("period_month", month)
            )
            for pay in payments {
                result.append((p, pay))
            }
        }
        return result
    }

    func markPaymentPaid(id: UUID, transactionId: UUID? = nil) async throws {
        struct Patch: Encodable {
            let paid: Bool
            let paid_at: String
            let transaction_id: UUID?
        }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
        try await SupabaseRPC.updateVoid(
            table: "installment_payments",
            payload: Patch(paid: true, paid_at: iso.string(from: Date()), transaction_id: transactionId),
            query: PgQuery().eq("id", id)
        )
    }
}
