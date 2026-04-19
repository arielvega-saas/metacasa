import Foundation
import Supabase

actor CreditCardService {
    static let shared = CreditCardService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    func fetchDetails(accountId: UUID) async throws -> CreditCardDetails? {
        let rows: [CreditCardDetails] = try await client
            .from("credit_cards")
            .select()
            .eq("account_id", value: accountId)
            .execute()
            .value
        return rows.first
    }

    func upsert(_ details: CreditCardDetails) async throws -> CreditCardDetails {
        try await client
            .from("credit_cards")
            .upsert(details, onConflict: "account_id")
            .select()
            .single()
            .execute()
            .value
    }

    /// Cálculo del pago mínimo sugerido según porcentaje configurado.
    static func minimumPayment(statementAmount: Decimal, percent: Decimal) -> Decimal {
        let pct = max(0, min(100, percent)) / 100
        return statementAmount * pct
    }

    /// Interés estimado si solo se paga el mínimo (mes siguiente).
    static func interestIfMinPayment(statementAmount: Decimal, minPct: Decimal, monthlyRate: Decimal) -> Decimal {
        let min = minimumPayment(statementAmount: statementAmount, percent: minPct)
        let balance = statementAmount - min
        return balance * monthlyRate / 100
    }

    /// Días hasta el próximo vencimiento según el dueDay (ej: 15 → día 15 del próximo mes).
    static func daysUntilDue(dueDay: Int, from date: Date = Date()) -> Int {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: date)
        comps.day = dueDay
        guard var next = cal.date(from: comps) else { return 0 }
        if next < date {
            next = cal.date(byAdding: .month, value: 1, to: next) ?? next
        }
        let diff = cal.dateComponents([.day], from: date, to: next).day ?? 0
        return max(0, diff)
    }
}
