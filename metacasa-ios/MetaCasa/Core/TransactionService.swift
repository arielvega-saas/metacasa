import Foundation

actor TransactionService {
    static let shared = TransactionService()
    private init() {}

    /// Read-through cache (ítem 4.1): red primero; si la red falla y el cache
    /// cubre la ventana pedida, se sirven los datos locales y se avisa al
    /// usuario vía `OfflineStatus`. Un 401 / 4xx NO cae al cache — se propaga
    /// para que `SupabaseRPC` renueve la sesión.
    func fetchForPeriod(householdId: UUID, from: Date, to: Date, limit: Int = 200) async throws -> [Transaction] {
        do {
            let rows: [Transaction] = try await SupabaseRPC.select(
                from: "transactions",
                query: PgQuery()
                    .eq("household_id", householdId)
                    .gte("date", from)
                    // El extremo se extiende al FINAL de su día. Sin esto, un `to` que venga a
                    // medianoche —como `budget_periods.period_end`, que es un `date`— deja afuera
                    // todas las transacciones del último día cargadas después de las 00:00, que
                    // en la práctica son casi todas. `totals()` delega acá, así que este único
                    // punto cubre totales, sobres y reportes.
                    .lte("date", to.endOfDayUTC())
                    .order("date", ascending: false)
                    .limit(limit)
            )
            // Escritura en background: la UI no espera al disco.
            Task.detached(priority: .utility) {
                await OfflineCache.shared.replace(
                    transactions: rows,
                    householdId: householdId,
                    from: from,
                    to: to,
                    requestedLimit: limit
                )
            }
            OfflineStatus.reportFreshData()
            return rows
        } catch {
            guard OfflineFallbackPolicy.allowsCachedFallback(for: error),
                  let cached = await OfflineCache.shared.loadTransactions(
                      householdId: householdId, from: from, to: to, limit: limit
                  )
            else { throw error }
            OfflineStatus.reportCachedData(syncedAt: cached.syncedAt)
            return cached.items
        }
    }

    func insert(_ input: NewTransactionInput) async throws -> Transaction {
        try await SupabaseRPC.insert(into: "transactions", payload: input)
    }

    func delete(id: UUID) async throws {
        try await SupabaseRPC.delete(
            from: "transactions",
            query: PgQuery().eq("id", id)
        )
    }

    func update(_ transaction: Transaction) async throws -> Transaction {
        // Solo mandamos los campos editables (evita colisiones con columnas
        // generadas / read-only como period_year / period_month).
        struct Patch: Encodable {
            let account_id: UUID?
            let type: String
            let amount: Decimal
            let currency_original: String?
            let category: String
            let subcategory: String?
            let account: String?
            let note: String?
            let date: Date
        }
        let patch = Patch(
            account_id: transaction.accountId,
            type: transaction.type.rawValue,
            amount: transaction.amount,
            currency_original: transaction.currencyOriginal,
            category: transaction.category,
            subcategory: transaction.subcategory,
            account: transaction.account,
            note: transaction.note,
            date: transaction.date
        )
        return try await SupabaseRPC.update(
            table: "transactions",
            payload: patch,
            query: PgQuery().eq("id", transaction.id)
        )
    }

    func fetchOne(id: UUID) async throws -> Transaction? {
        try await SupabaseRPC.selectFirst(
            from: "transactions",
            query: PgQuery().eq("id", id)
        )
    }

    func totals(householdId: UUID, from: Date, to: Date) async throws -> (ingresos: Decimal, gastos: Decimal) {
        let txs = try await fetchForPeriod(householdId: householdId, from: from, to: to, limit: 1000)
        let ing = txs.filter { $0.type == .ingreso }.reduce(Decimal(0)) { $0 + $1.amount }
        let gast = txs.filter { $0.type == .gasto }.reduce(Decimal(0)) { $0 + $1.amount }
        return (ing, gast)
    }
}
