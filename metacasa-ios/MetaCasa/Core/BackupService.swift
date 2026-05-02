import Foundation

/// Backup/restore completo del hogar en JSON. Paridad con el "Backup" / "Restore"
/// de la PWA (App.jsx ~5102-5170 en la web).
///
/// Formato del archivo: JSON con `version` (schema), `exportedAt`, `householdId`
/// y arrays de cada entidad. El consumo es solo por esta misma app (iOS); no
/// pretende ser compatible con la web al byte — es intercambio lógico.
actor BackupService {
    static let shared = BackupService()
    private init() {}

    /// Estructura del JSON que se exporta. Aumentar `schemaVersion` cuando se
    /// cambie el shape para que `restore` pueda detectar versiones viejas.
    struct Payload: Codable, Sendable {
        let version: Int
        let exportedAt: Date
        let householdId: UUID
        let household: Household?
        let accounts: [Account]
        let categoriesBlob: CategoriesBlob?
        let transactions: [Transaction]
        let recurring: [RecurringTransaction]
        let budgetPeriods: [BudgetPeriod]
        let budgetAllocations: [BudgetAllocation]
        let goals: [Goal]
        let goalContributions: [GoalContribution]
        let creditCards: [CreditCardDetails]

        static let schemaVersion = 1
    }

    struct RestoreReport: Sendable {
        var transactions = 0
        var transactionsDuplicated = 0
        var accounts = 0
        var recurring = 0
        var goals = 0
        var categoriesRestored = false
        var skipped: [String] = []
    }

    enum BackupError: LocalizedError {
        case incompatibleVersion(Int)
        case householdMissing
        case userMissing

        var errorDescription: String? {
            switch self {
            case .incompatibleVersion(let v):
                return "El backup tiene un formato incompatible (v\(v))."
            case .householdMissing:
                return "No hay hogar seleccionado."
            case .userMissing:
                return "No hay usuario activo."
            }
        }
    }

    // MARK: - Build

    /// Construye el payload leyendo TODAS las entidades del hogar indicado.
    /// Los rangos de fechas son amplios (10 años para tx, 2 años para budget
    /// periods) para capturar el historial completo sin bloquear.
    func build(householdId: UUID, fromDate: Date? = nil, toDate: Date? = nil) async throws -> Payload {
        let now = Date()
        let cal = Calendar.current
        let from = fromDate ?? cal.date(byAdding: .year, value: -10, to: now) ?? now
        let to = toDate ?? now

        async let householdsTask = HouseholdService.shared.fetchMine()
        async let accountsTask = AccountService.shared.fetchAll(householdId: householdId, includingInactive: true)
        async let categoriesTask = CategoryService.shared.fetch(householdId: householdId)
        async let transactionsTask = TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: from, to: to, limit: 50_000
        )
        async let recurringTask = RecurringService.shared.fetchAll(
            householdId: householdId, includeInactive: true
        )
        async let goalsTask = GoalService.shared.fetchAll(
            householdId: householdId, includeCompleted: true
        )

        let households = try await householdsTask
        let household = households.first(where: { $0.id == householdId })
        let accounts = try await accountsTask
        let categoriesBlob = try await categoriesTask
        let transactions = try await transactionsTask
        let recurring = try await recurringTask
        let goals = try await goalsTask

        let periodsFrom = cal.date(byAdding: .year, value: -2, to: now) ?? now
        let periods: [BudgetPeriod] = try await SupabaseRPC.select(
            from: "budget_periods",
            query: PgQuery()
                .eq("household_id", householdId)
                .gte("period_start", periodsFrom)
                .order("period_start", ascending: false)
        )

        var allocations: [BudgetAllocation] = []
        for p in periods {
            let a = try await BudgetService.shared.fetchAllocations(periodId: p.id)
            allocations.append(contentsOf: a)
        }

        var contributions: [GoalContribution] = []
        for g in goals {
            let c = try await GoalService.shared.fetchContributions(goalId: g.id)
            contributions.append(contentsOf: c)
        }

        var cards: [CreditCardDetails] = []
        for acc in accounts where acc.type == .creditCard {
            if let d = try? await CreditCardService.shared.fetchDetails(accountId: acc.id) {
                cards.append(d)
            }
        }

        return Payload(
            version: Payload.schemaVersion,
            exportedAt: now,
            householdId: householdId,
            household: household,
            accounts: accounts,
            categoriesBlob: categoriesBlob,
            transactions: transactions,
            recurring: recurring,
            budgetPeriods: periods,
            budgetAllocations: allocations,
            goals: goals,
            goalContributions: contributions,
            creditCards: cards
        )
    }

    // MARK: - File I/O

    /// Serializa a JSON pretty-printed y escribe en un archivo temporal.
    func writeJSONFile(_ payload: Payload) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let stamp = formatter.string(from: payload.exportedAt)
        let name = "metacasa_backup_\(stamp).json"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    func readJSONFile(_ url: URL) throws -> Payload {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Payload.self, from: data)
        guard payload.version <= Payload.schemaVersion else {
            throw BackupError.incompatibleVersion(payload.version)
        }
        return payload
    }

    // MARK: - Restore

    /// Restaura accounts + categorías + transactions + recurring + goals al hogar
    /// activo del usuario. No borra datos existentes — agrega. Presupuestos
    /// históricos se dejan fuera del MVP (colisión de ids de period entre hogares).
    func restore(payload: Payload, targetHouseholdId: UUID, userId: UUID) async throws -> RestoreReport {
        var report = RestoreReport()

        for acc in payload.accounts {
            do {
                _ = try await AccountService.shared.create(
                    userId: userId,
                    householdId: targetHouseholdId,
                    name: acc.name,
                    type: acc.type,
                    currency: acc.currency,
                    startingBalance: acc.startingBalance,
                    institution: acc.institution,
                    icon: acc.icon,
                    color: acc.color
                )
                report.accounts += 1
            } catch {
                report.skipped.append("account:\(acc.name)")
            }
        }

        if let blob = payload.categoriesBlob {
            do {
                _ = try await CategoryService.shared.save(
                    householdId: targetHouseholdId,
                    data: blob.data
                )
                report.categoriesRestored = true
            } catch {
                report.skipped.append("categories")
            }
        }

        // Build fingerprint set de transactions existentes para dedup.
        // Fingerprint: "yyyy-MM-dd_type_amount_category_note".
        let existingFingerprints = await Self.fetchExistingFingerprints(
            householdId: targetHouseholdId,
            payload: payload
        )

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")

        for tx in payload.transactions {
            let fp = Self.fingerprint(
                date: tx.date,
                type: tx.type,
                amount: tx.amount,
                category: tx.category,
                note: tx.note,
                df: df
            )
            if existingFingerprints.contains(fp) {
                report.transactionsDuplicated += 1
                continue
            }

            let input = NewTransactionInput(
                householdId: targetHouseholdId,
                userId: userId,
                accountId: nil,
                type: tx.type,
                amount: tx.amount,
                currencyOriginal: tx.currencyOriginal,
                category: tx.category,
                subcategory: tx.subcategory,
                note: tx.note,
                date: tx.date
            )
            do {
                _ = try await TransactionService.shared.insert(input)
                report.transactions += 1
            } catch {
                report.skipped.append("tx:\(tx.id.uuidString.prefix(8))")
            }
        }

        for r in payload.recurring {
            do {
                _ = try await RecurringService.shared.create(
                    userId: userId,
                    householdId: targetHouseholdId,
                    type: r.type,
                    amount: r.amount,
                    category: r.category,
                    frequency: r.frequency,
                    startDate: r.startDate,
                    endDate: r.endDate,
                    note: r.note
                )
                report.recurring += 1
            } catch {
                report.skipped.append("recurring:\(r.id.uuidString.prefix(8))")
            }
        }

        for g in payload.goals {
            do {
                _ = try await GoalService.shared.create(
                    userId: userId,
                    householdId: targetHouseholdId,
                    name: g.name,
                    targetAmount: g.targetAmount,
                    currency: g.currency,
                    targetDate: g.targetDate,
                    icon: g.icon,
                    color: g.color,
                    priority: g.priority,
                    category: g.category
                )
                report.goals += 1
            } catch {
                report.skipped.append("goal:\(g.name)")
            }
        }

        return report
    }

    // MARK: - Dedup helpers

    /// Genera un fingerprint para detectar duplicados. Dos transacciones con
    /// la misma fecha + tipo + monto + categoría + nota se consideran iguales.
    static func fingerprint(
        date: Date,
        type: TxType,
        amount: Decimal,
        category: String,
        note: String?,
        df: DateFormatter
    ) -> String {
        let dateStr = df.string(from: date)
        let noteStr = note ?? ""
        return "\(dateStr)|\(type.rawValue)|\(amount)|\(category)|\(noteStr)"
    }

    /// Trae las transactions del hogar en el rango temporal del payload y
    /// devuelve el Set de fingerprints. Se usa para evitar re-insertar al
    /// restaurar un backup.
    static func fetchExistingFingerprints(
        householdId: UUID,
        payload: Payload
    ) async -> Set<String> {
        // Calcular rango de fechas del payload (min a max de sus transactions).
        let dates = payload.transactions.map { $0.date }
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            return []
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")

        guard let existing = try? await TransactionService.shared.fetchForPeriod(
            householdId: householdId,
            from: minDate,
            to: maxDate,
            limit: 50_000
        ) else {
            return []
        }

        var set: Set<String> = []
        for tx in existing {
            let fp = fingerprint(
                date: tx.date,
                type: tx.type,
                amount: tx.amount,
                category: tx.category,
                note: tx.note,
                df: df
            )
            set.insert(fp)
        }
        return set
    }
}
