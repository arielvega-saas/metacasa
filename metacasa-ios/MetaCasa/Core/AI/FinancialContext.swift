import Foundation

/// Snapshot compacto del estado financiero del hogar, usado como contexto
/// para el asistente IA. Se construye cada vez que el usuario envía un
/// mensaje, para que las respuestas siempre reflejen los datos actuales.
///
/// En Sprint 3 este mismo struct se serializa a JSON y se inyecta como
/// contexto en FoundationModels. Hoy (Sprint 2 MVP) lo consume el motor
/// estadístico local en `AIAssistantService`.
struct FinancialContext: Sendable {
    let householdId: UUID
    let householdName: String
    let currency: String

    // Mes actual
    let ingresosMonth: Decimal
    let gastosMonth: Decimal
    var balanceMonth: Decimal { ingresosMonth - gastosMonth }

    // Mes anterior
    let prevMonthIngresos: Decimal
    let prevMonthGastos: Decimal
    var balancePrevMonth: Decimal { prevMonthIngresos - prevMonthGastos }

    // Breakdown del mes
    let topCategories: [CategoryTotal]

    // Otros counters
    let activeGoalsCount: Int
    let activeGoalsSummary: [GoalSummary]
    let upcomingBillsCount: Int
    let activeDebtsCount: Int

    // Sprint 14: señales extra para análisis pro
    /// Mayor gasto único del mes. Permite al modelo detectar outliers.
    let biggestExpenseThisMonth: ExpenseSignal?
    /// Gasto total por cada una de las últimas 4 semanas (más reciente primero).
    /// Si hay <4 semanas de data el array es más corto.
    let weeklySpending: [Decimal]
    /// Categorías que YA sobrepasaron (100%+) su allocation del mes actual.
    let envelopesOverBudget: [String]
    /// Categorías que están sobre el 80% de allocation (warning zone).
    let envelopesNearLimit: [String]
    /// Ratio deuda mensual comprometida / ingresos del mes. 0.0–1.0+.
    /// Ayuda al modelo a señalar si la carga de deuda es alta (>0.4).
    let debtLoadRatio: Double
    /// Últimas 5 transacciones (resumen string para inyectar en prompt).
    let recentTransactionsPreview: [String]
    /// Total de cuentas (assets) — suma startingBalance de accounts non-credit/loan.
    /// Aproximación de liquid assets. Útil para contextualizar emergency fund.
    let liquidAssets: Decimal
    /// Anomalías detectadas en las transacciones del mes (outliers, categorías
    /// nuevas, duplicados potenciales). El modelo puede señalarlas proactivamente.
    let anomalies: [String]

    struct CategoryTotal: Sendable, Equatable {
        let category: String
        let total: Decimal
    }

    struct GoalSummary: Sendable, Equatable {
        let name: String
        let progress: Double
        let remaining: Decimal
        let currency: String
    }

    struct ExpenseSignal: Sendable, Equatable {
        let category: String
        let amount: Decimal
        let date: Date
        let note: String?
    }
}

@MainActor
enum FinancialContextBuilder {
    enum BuilderError: LocalizedError {
        case householdMissing
        case invalidDateRange

        var errorDescription: String? {
            switch self {
            case .householdMissing: "No hay hogar activo."
            case .invalidDateRange: "Fecha inválida al construir contexto."
            }
        }
    }

    static func build(appState: AppState) async throws -> FinancialContext {
        guard let hid = appState.currentHouseholdId else {
            throw BuilderError.householdMissing
        }
        let household = appState.households.first(where: { $0.id == hid })
        let currency = household?.defaultCurrency ?? "USD"
        let name = household?.name ?? "Hogar"

        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59), to: start),
              let prevStart = cal.date(byAdding: .month, value: -1, to: start),
              let prevEnd = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59), to: prevStart)
        else { throw BuilderError.invalidDateRange }

        async let totalsNow = TransactionService.shared.totals(householdId: hid, from: start, to: end)
        async let totalsPrev = TransactionService.shared.totals(householdId: hid, from: prevStart, to: prevEnd)
        async let txs = TransactionService.shared.fetchForPeriod(householdId: hid, from: start, to: end, limit: 5000)
        async let goals = GoalService.shared.fetchAll(householdId: hid, includeCompleted: false)
        async let bills = BillService.shared.fetchUpcoming(householdId: hid, daysAhead: 30)
        async let debts = DebtService.shared.fetchAll(householdId: hid, includeSettled: false)
        async let accounts = AccountService.shared.fetchAll(householdId: hid, includingInactive: false)
        // Trae últimas 4 semanas (28 días) para computar weekly spending.
        let fourWeeksAgo = cal.date(byAdding: .day, value: -28, to: now) ?? now
        async let recentTxsTask = TransactionService.shared.fetchForPeriod(
            householdId: hid, from: fourWeeksAgo, to: now, limit: 5000
        )
        // Budget period actual para envelope health.
        async let periodTask = BudgetService.shared.fetchPeriod(householdId: hid, containing: now)

        let t = try await totalsNow
        let p = try await totalsPrev
        let tl = (try? await txs) ?? []

        var byCat: [String: Decimal] = [:]
        for tx in tl where tx.type == .gasto {
            byCat[tx.category, default: 0] += tx.amount
        }
        let top = byCat.sorted { $0.value > $1.value }
            .map { FinancialContext.CategoryTotal(category: $0.key, total: $0.value) }

        let goalList = (try? await goals) ?? []
        let goalSummaries = goalList.prefix(5).map { g in
            FinancialContext.GoalSummary(
                name: g.name,
                progress: g.progress,
                remaining: max(0, g.targetAmount - g.currentAmount),
                currency: g.currency
            )
        }

        let billList = (try? await bills) ?? []
        let debtList = (try? await debts) ?? []
        let accountList = (try? await accounts) ?? []
        let recentTxs = (try? await recentTxsTask) ?? []

        // Biggest expense del mes actual
        let biggest: FinancialContext.ExpenseSignal? = tl
            .filter { $0.type == .gasto }
            .max(by: { $0.amount < $1.amount })
            .map {
                FinancialContext.ExpenseSignal(
                    category: $0.category,
                    amount: $0.amount,
                    date: $0.date,
                    note: $0.note
                )
            }

        // Weekly spending buckets — últimas 4 semanas, más reciente primero.
        var weekly: [Decimal] = Array(repeating: 0, count: 4)
        for tx in recentTxs where tx.type == .gasto {
            let daysAgo = cal.dateComponents([.day], from: tx.date, to: now).day ?? 0
            let weekIdx = max(0, min(3, daysAgo / 7))
            weekly[weekIdx] += tx.amount
        }

        // Envelope health: buscar allocations del period actual, comparar
        // contra gasto real por categoría.
        var overBudget: [String] = []
        var nearLimit: [String] = []
        if let period = try? await periodTask {
            let allocs = (try? await BudgetService.shared.fetchAllocations(periodId: period.id)) ?? []
            for alloc in allocs where alloc.allocated > 0 {
                let spent = byCat[alloc.category] ?? 0
                let pct = (spent / alloc.allocated) as NSDecimalNumber
                let pctDouble = pct.doubleValue
                if pctDouble >= 1.0 {
                    overBudget.append(alloc.category)
                } else if pctDouble >= 0.8 {
                    nearLimit.append(alloc.category)
                }
            }
        }

        // Debt load ratio: suma monthly payment estimado de deudas activas / ingresos del mes.
        // Como el modelo Debt no siempre tiene monthly payment field, usamos
        // currentBalance como proxy heurístico: asumimos payoff en 24 meses.
        let monthlyDebtEstimate: Decimal = debtList.reduce(0) { $0 + ($1.currentBalance / 24) }
        let debtLoadRatio: Double = {
            guard t.ingresos > 0 else { return 0 }
            let r = (monthlyDebtEstimate / t.ingresos) as NSDecimalNumber
            return max(0, r.doubleValue)
        }()

        // Recent transactions preview (últimas 5).
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_AR")
        df.setLocalizedDateFormatFromTemplate("ddMMM")
        let recentPreview: [String] = tl.prefix(5).map { tx in
            let sign = tx.type == .gasto ? "−" : "+"
            let noteStr = tx.note.flatMap { $0.isEmpty ? nil : " — \($0)" } ?? ""
            return "  \(df.string(from: tx.date)): \(sign)\(Money.format(tx.amount, currency: tx.currencyOriginal ?? currency)) \(tx.category)\(noteStr)"
        }

        // Liquid assets: suma startingBalance de cuentas no-credit_card y no-loan.
        let liquid: Decimal = accountList
            .filter { $0.type != .creditCard && $0.type != .loan }
            .reduce(Decimal(0)) { $0 + $1.startingBalance }

        // Anomaly detection: baseline = 90 días previos al mes actual.
        let ninetyBack = cal.date(byAdding: .day, value: -90, to: start) ?? start
        let baseline = recentTxs.filter { $0.date < start && $0.date >= ninetyBack }
        let anomalies = AnomalyDetector.detect(
            currentMonthTxs: tl,
            baselineTxs: baseline,
            currency: currency
        ).map(\.message)

        return FinancialContext(
            householdId: hid,
            householdName: name,
            currency: currency,
            ingresosMonth: t.ingresos,
            gastosMonth: t.gastos,
            prevMonthIngresos: p.ingresos,
            prevMonthGastos: p.gastos,
            topCategories: top,
            activeGoalsCount: goalList.count,
            activeGoalsSummary: Array(goalSummaries),
            upcomingBillsCount: billList.count,
            activeDebtsCount: debtList.count,
            biggestExpenseThisMonth: biggest,
            weeklySpending: weekly,
            envelopesOverBudget: overBudget,
            envelopesNearLimit: nearLimit,
            debtLoadRatio: debtLoadRatio,
            recentTransactionsPreview: recentPreview,
            liquidAssets: liquid,
            anomalies: anomalies
        )
    }
}
