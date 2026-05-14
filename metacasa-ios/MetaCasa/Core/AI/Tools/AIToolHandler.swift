import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AIToolHandler: @unchecked Sendable {
    private let householdId: UUID
    private let userId: UUID
    private let currency: String

    init(householdId: UUID, userId: UUID, currency: String) {
        self.householdId = householdId
        self.userId = userId
        self.currency = currency
    }

    // MARK: - Date helpers

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return Self.dayFmt.date(from: s)
    }

    private func monthRange(_ monthStr: String?) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        if let m = monthStr {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            if let d = fmt.date(from: m) {
                let comps = cal.dateComponents([.year, .month], from: d)
                let start = cal.date(from: comps) ?? now
                let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? now
                return (start, end)
            }
        }
        let comps = cal.dateComponents([.year, .month], from: now)
        let start = cal.date(from: comps) ?? now
        let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? now
        return (start, end)
    }

    private func fmtDate(_ d: Date) -> String {
        Self.dayFmt.string(from: d)
    }

    /// Formato CON código ISO explícito (ej. "ARS 6.000", "USD 100").
    /// Esto evita que el LLM interprete el "$" como USD (bias del training).
    /// Cuando el LLM lee tool results con código explícito, sabe la moneda exacta
    /// y la respeta en su respuesta al usuario.
    private func fmt(_ amount: Decimal, cur: String? = nil) -> String {
        let currencyCode = cur ?? currency
        let value = (amount as NSDecimalNumber).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = ","
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(currencyCode) \(formatted)"
    }

    // MARK: - 1. Query Transactions

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    func queryTransactions(_ p: QueryTransactionsTool.Arguments) async throws -> String {
        let from = parseDate(p.dateFrom) ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let to = parseDate(p.dateTo) ?? Date()
        let limit = min(p.limit ?? 20, 50)

        var txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: from, to: to, limit: 5000
        )

        if let cat = p.category {
            let lc = cat.lowercased()
            txs = txs.filter { $0.category.lowercased().contains(lc) }
        }
        if let t = p.type {
            let txType: TxType = t.uppercased() == "INGRESO" ? .ingreso : .gasto
            txs = txs.filter { $0.type == txType }
        }
        if let note = p.noteContains {
            let lc = note.lowercased()
            txs = txs.filter { ($0.note ?? "").lowercased().contains(lc) }
        }
        if let min = p.amountMin {
            txs = txs.filter { ($0.amount as NSDecimalNumber).doubleValue >= min }
        }
        if let max = p.amountMax {
            txs = txs.filter { ($0.amount as NSDecimalNumber).doubleValue <= max }
        }

        let totalAmount = txs.reduce(Decimal.zero) { $0 + $1.amount }
        let display = txs.prefix(limit)

        var lines: [String] = []
        lines.append("Found \(txs.count) transactions. Total: \(fmt(totalAmount)).")
        if txs.count > limit { lines.append("Showing first \(limit):") }
        lines.append("")

        for tx in display {
            let sign = tx.type == .gasto ? "-" : "+"
            let note = tx.note.flatMap { $0.isEmpty ? nil : " (\($0))" } ?? ""
            lines.append("• \(fmtDate(tx.date)): \(sign)\(fmt(tx.amount)) \(tx.category)\(note) [id:\(tx.id.uuidString.prefix(8))]")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 2. Add Transaction

    @available(iOS 26.0, *)
    func addTransaction(_ p: AddTransactionTool.Arguments) async throws -> String {
        let txType: TxType = p.type.uppercased() == "INGRESO" ? .ingreso : .gasto
        let date = parseDate(p.date) ?? Date()
        let amount = Decimal(p.amount)

        let input = NewTransactionInput(
            householdId: householdId,
            userId: userId,
            accountId: nil,
            type: txType,
            amount: amount,
            currencyOriginal: currency,
            category: p.category,
            subcategory: p.subcategory,
            note: p.note,
            date: date
        )

        let created = try await TransactionService.shared.insert(input)
        let typeLabel = txType == .gasto ? "expense" : "income"
        return "Transaction created: \(typeLabel) of \(fmt(amount)) in \(p.category) on \(fmtDate(date)). ID: \(created.id.uuidString.prefix(8))."
    }

    // MARK: - 3. Update Transaction

    @available(iOS 26.0, *)
    func updateTransaction(_ p: UpdateTransactionTool.Arguments) async throws -> String {
        guard let uuid = UUID(uuidString: expandUUID(p.transactionId)) else {
            return "Error: invalid transaction ID format."
        }
        guard var tx = try await TransactionService.shared.fetchOne(id: uuid) else {
            return "Error: transaction not found."
        }

        if let a = p.amount { tx.amount = Decimal(a) }
        if let c = p.category { tx.category = c }
        if let s = p.subcategory { tx.subcategory = s }
        if let n = p.note { tx.note = n }
        if let d = p.date, let date = parseDate(d) { tx.date = date }
        if let t = p.type { tx.type = t.uppercased() == "INGRESO" ? .ingreso : .gasto }

        let updated = try await TransactionService.shared.update(tx)
        return "Transaction updated: \(fmt(updated.amount)) in \(updated.category) on \(fmtDate(updated.date))."
    }

    // MARK: - 4. Delete Transaction

    @available(iOS 26.0, *)
    func deleteTransaction(_ p: DeleteTransactionTool.Arguments) async throws -> String {
        guard let uuid = UUID(uuidString: expandUUID(p.transactionId)) else {
            return "Error: invalid transaction ID format."
        }
        try await TransactionService.shared.delete(id: uuid)
        return "Transaction deleted."
    }

    // MARK: - 5. Financial Summary

    @available(iOS 26.0, *)
    func getFinancialSummary(_ p: GetFinancialSummaryTool.Arguments) async throws -> String {
        let range = monthRange(p.month)
        let totals = try await TransactionService.shared.totals(
            householdId: householdId, from: range.start, to: range.end
        )

        let balance = totals.ingresos - totals.gastos
        let savingsRate: Int = totals.ingresos > 0
            ? Int(((balance / totals.ingresos) as NSDecimalNumber).doubleValue * 100)
            : 0

        var lines: [String] = []
        lines.append("Financial Summary:")
        lines.append("• Income: \(fmt(totals.ingresos))")
        lines.append("• Expenses: \(fmt(totals.gastos))")
        lines.append("• Balance: \(fmt(balance))")
        lines.append("• Savings rate: \(savingsRate)%")

        if p.includeComparison == true {
            let cal = Calendar.current
            let prevStart = cal.date(byAdding: .month, value: -1, to: range.start) ?? range.start
            let prevEnd = cal.date(byAdding: .month, value: -1, to: range.end) ?? range.end
            let prev = try await TransactionService.shared.totals(
                householdId: householdId, from: prevStart, to: prevEnd
            )
            let deltaExp = totals.gastos - prev.gastos
            let deltaInc = totals.ingresos - prev.ingresos
            lines.append("")
            lines.append("vs Previous month:")
            lines.append("• Income change: \(deltaInc >= 0 ? "+" : "")\(fmt(deltaInc))")
            lines.append("• Expense change: \(deltaExp >= 0 ? "+" : "")\(fmt(deltaExp))")
        }

        let txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: range.start, to: range.end, limit: 5000
        )
        var byCat: [String: Decimal] = [:]
        for tx in txs where tx.type == .gasto {
            byCat[tx.category, default: 0] += tx.amount
        }
        let sorted = byCat.sorted { $0.value > $1.value }
        if !sorted.isEmpty {
            lines.append("")
            lines.append("Top categories:")
            for (i, item) in sorted.prefix(7).enumerated() {
                let pct = totals.gastos > 0
                    ? Int(((item.value / totals.gastos) as NSDecimalNumber).doubleValue * 100)
                    : 0
                lines.append("  \(i+1). \(item.key): \(fmt(item.value)) (\(pct)%)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 6. Budget Status

    @available(iOS 26.0, *)
    func getBudgetStatus(_ p: GetBudgetStatusTool.Arguments) async throws -> String {
        let range = monthRange(p.month)
        guard let period = try await BudgetService.shared.fetchPeriod(
            householdId: householdId, containing: range.start
        ) else {
            return "No budget period found for this month. Create one in the Budget tab."
        }

        let allocs = try await BudgetService.shared.fetchAllocations(periodId: period.id)
        let txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: range.start, to: range.end, limit: 5000
        )

        var spent: [String: Decimal] = [:]
        for tx in txs where tx.type == .gasto {
            spent[tx.category, default: 0] += tx.amount
        }

        var lines: [String] = ["Budget Status:"]
        lines.append("Total allocated: \(fmt(period.totalAllocated))")
        lines.append("Ready to assign: \(fmt(period.readyToAssign))")
        lines.append("")

        var overBudget: [String] = []
        var nearLimit: [String] = []

        for alloc in allocs.sorted(by: { $0.allocated > $1.allocated }) where alloc.allocated > 0 {
            let s = spent[alloc.category] ?? 0
            let remaining = alloc.allocated - s
            let pct = ((s / alloc.allocated) as NSDecimalNumber).doubleValue * 100
            let status: String
            if pct >= 100 {
                status = "OVER"
                overBudget.append(alloc.category)
            } else if pct >= 80 {
                status = "WARNING"
                nearLimit.append(alloc.category)
            } else {
                status = "OK"
            }
            lines.append("• \(alloc.category): \(fmt(s))/\(fmt(alloc.allocated)) (\(Int(pct))%) [\(status)] remaining: \(fmt(remaining))")
        }

        if !overBudget.isEmpty {
            lines.append("\nOver budget: \(overBudget.joined(separator: ", "))")
        }
        if !nearLimit.isEmpty {
            lines.append("Near limit (80%+): \(nearLimit.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 7. Net Worth

    @available(iOS 26.0, *)
    func getNetWorth() async throws -> String {
        let accounts = try await AccountService.shared.fetchAll(householdId: householdId, includingInactive: false)
        let debts = try await DebtService.shared.fetchAll(householdId: householdId, includeSettled: false)

        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .year, value: -1, to: now) ?? now
        let txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: start, to: now, limit: 10000
        )

        var lines: [String] = ["Net Worth Breakdown:"]
        var totalAssets: Decimal = 0
        var totalLiabilities: Decimal = 0

        lines.append("\nAssets:")
        for acc in accounts where acc.type != .creditCard && acc.type != .loan {
            let bal = AccountBalanceService.currentBalance(account: acc, transactions: txs)
            totalAssets += bal
            lines.append("  • \(acc.name) (\(acc.type.rawValue)): \(fmt(bal, cur: acc.currency))")
        }

        lines.append("\nLiabilities:")
        for acc in accounts where acc.type == .creditCard || acc.type == .loan {
            let bal = AccountBalanceService.currentBalance(account: acc, transactions: txs)
            let owed = abs(bal)
            totalLiabilities += owed
            lines.append("  • \(acc.name): \(fmt(owed, cur: acc.currency))")
        }
        for debt in debts {
            totalLiabilities += debt.currentBalance
            lines.append("  • \(debt.creditor) (debt): \(fmt(debt.currentBalance, cur: debt.currency))")
        }

        let netWorth = totalAssets - totalLiabilities
        lines.append("\nTotal Assets: \(fmt(totalAssets))")
        lines.append("Total Liabilities: \(fmt(totalLiabilities))")
        lines.append("Net Worth: \(fmt(netWorth))")

        return lines.joined(separator: "\n")
    }

    // MARK: - 8. Health Score

    @available(iOS 26.0, *)
    func getHealthScore() async throws -> String {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let monthStart = cal.date(from: comps)!
        let monthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart)!

        let totals = try await TransactionService.shared.totals(
            householdId: householdId, from: monthStart, to: monthEnd
        )
        let goals = try await GoalService.shared.fetchAll(householdId: householdId, includeCompleted: false)
        let debts = try await DebtService.shared.fetchAll(householdId: householdId, includeSettled: false)
        let accounts = try await AccountService.shared.fetchAll(householdId: householdId, includingInactive: false)

        let balance = totals.ingresos - totals.gastos
        let savingsRate: Double = totals.ingresos > 0
            ? ((balance / totals.ingresos) as NSDecimalNumber).doubleValue
            : 0

        let monthlyDebt = debts.reduce(Decimal.zero) { $0 + ($1.currentBalance / 24) }
        let debtRatio: Double = totals.ingresos > 0
            ? ((monthlyDebt / totals.ingresos) as NSDecimalNumber).doubleValue
            : 0

        let liquid = accounts
            .filter { $0.type != .creditCard && $0.type != .loan }
            .reduce(Decimal.zero) { $0 + $1.startingBalance }
        let monthsOfRunway: Double = totals.gastos > 0
            ? ((liquid / totals.gastos) as NSDecimalNumber).doubleValue
            : 0

        let avgGoalProgress: Double = goals.isEmpty ? 0 :
            goals.reduce(0.0) { $0 + $1.progress } / Double(goals.count)

        // Score components (each 0-20, total 0-100)
        let savingsScore = min(20, Int(savingsRate * 100))
        let debtScore = max(0, 20 - Int(debtRatio * 50))
        let emergencyScore = min(20, Int(monthsOfRunway / 6.0 * 20))
        let goalScore = Int(avgGoalProgress * 20)
        let budgetScore: Int
        if let period = try? await BudgetService.shared.fetchPeriod(householdId: householdId, containing: now) {
            let allocs = (try? await BudgetService.shared.fetchAllocations(periodId: period.id)) ?? []
            budgetScore = allocs.isEmpty ? 5 : 15
        } else {
            budgetScore = 0
        }

        let total = savingsScore + debtScore + emergencyScore + goalScore + budgetScore

        var lines: [String] = ["Financial Health Score: \(total)/100"]
        lines.append("")
        lines.append("Breakdown:")
        lines.append("  • Savings rate (\(Int(savingsRate * 100))%): \(savingsScore)/20")
        lines.append("  • Debt load (\(Int(debtRatio * 100))%): \(debtScore)/20")
        lines.append("  • Emergency fund (\(String(format: "%.1f", monthsOfRunway)) months): \(emergencyScore)/20")
        lines.append("  • Goal progress (\(Int(avgGoalProgress * 100))%): \(goalScore)/20")
        lines.append("  • Budget setup: \(budgetScore)/20")

        let grade: String
        switch total {
        case 80...: grade = "Excellent"
        case 60..<80: grade = "Good"
        case 40..<60: grade = "Needs improvement"
        default: grade = "Critical - take action"
        }
        lines.append("\nGrade: \(grade)")

        return lines.joined(separator: "\n")
    }

    // MARK: - 9. Project Scenario

    @available(iOS 26.0, *)
    func projectScenario(_ p: ProjectScenarioTool.Arguments) async throws -> String {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let monthStart = cal.date(from: comps)!
        let monthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart)!
        let months = p.months ?? 3

        let totals = try await TransactionService.shared.totals(
            householdId: householdId, from: monthStart, to: monthEnd
        )

        var projectedIncome = totals.ingresos
        var projectedExpenses = totals.gastos

        if let cat = p.category, let pct = p.percentChange {
            let txs = try await TransactionService.shared.fetchForPeriod(
                householdId: householdId, from: monthStart, to: monthEnd, limit: 5000
            )
            let catSpend = txs.filter { $0.type == .gasto && $0.category.lowercased() == cat.lowercased() }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let change = catSpend * Decimal(pct / 100.0)
            projectedExpenses += change
        } else if let fixed = p.fixedAmountChange {
            let fixedDec = Decimal(fixed)
            if fixedDec > 0 {
                projectedIncome += fixedDec
            } else {
                projectedExpenses += abs(fixedDec)
            }
        }

        let currentBalance = totals.ingresos - totals.gastos
        let projectedBalance = projectedIncome - projectedExpenses
        let monthlySavingsDelta = projectedBalance - currentBalance

        var lines: [String] = ["Scenario: \(p.scenario)"]
        lines.append("")
        lines.append("Current monthly:")
        lines.append("  Income: \(fmt(totals.ingresos)), Expenses: \(fmt(totals.gastos)), Balance: \(fmt(currentBalance))")
        lines.append("")
        lines.append("Projected monthly:")
        lines.append("  Income: \(fmt(projectedIncome)), Expenses: \(fmt(projectedExpenses)), Balance: \(fmt(projectedBalance))")
        lines.append("")
        lines.append("Monthly impact: \(monthlySavingsDelta >= 0 ? "+" : "")\(fmt(monthlySavingsDelta))")
        lines.append("\(months)-month cumulative impact: \(monthlySavingsDelta >= 0 ? "+" : "")\(fmt(monthlySavingsDelta * Decimal(months)))")

        return lines.joined(separator: "\n")
    }

    // MARK: - 10. Spending Patterns

    @available(iOS 26.0, *)
    func detectSpendingPatterns(_ p: DetectSpendingPatternsTool.Arguments) async throws -> String {
        let monthsBack = min(p.monthsBack ?? 3, 12)
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .month, value: -monthsBack, to: now) ?? now

        var txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: start, to: now, limit: 10000
        )
        txs = txs.filter { $0.type == .gasto }

        if let cat = p.category {
            let lc = cat.lowercased()
            txs = txs.filter { $0.category.lowercased().contains(lc) }
        }

        guard !txs.isEmpty else {
            return "No expense data found for the past \(monthsBack) months."
        }

        // Monthly totals
        var monthlyTotals: [String: Decimal] = [:]
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "yyyy-MM"
        for tx in txs {
            let key = monthFmt.string(from: tx.date)
            monthlyTotals[key, default: 0] += tx.amount
        }

        // Day-of-week distribution
        var dayOfWeek: [Int: Decimal] = [:]
        for tx in txs {
            let dow = cal.component(.weekday, from: tx.date)
            dayOfWeek[dow, default: 0] += tx.amount
        }
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Category breakdown
        var byCat: [String: Decimal] = [:]
        for tx in txs { byCat[tx.category, default: 0] += tx.amount }

        var lines: [String] = ["Spending Patterns (\(monthsBack) months):"]

        lines.append("\nMonthly trend:")
        for key in monthlyTotals.keys.sorted() {
            lines.append("  \(key): \(fmt(monthlyTotals[key]!))")
        }

        let sortedMonths = monthlyTotals.keys.sorted()
        if sortedMonths.count >= 2 {
            let first = monthlyTotals[sortedMonths.first!]!
            let last = monthlyTotals[sortedMonths.last!]!
            if first > 0 {
                let growthPct = ((last - first) / first) as NSDecimalNumber
                lines.append("  Trend: \(Int(growthPct.doubleValue * 100))% change from first to last month")
            }
        }

        lines.append("\nBy day of week:")
        for dow in 1...7 {
            let total = dayOfWeek[dow] ?? 0
            lines.append("  \(dayNames[dow]): \(fmt(total))")
        }

        if p.category == nil {
            lines.append("\nTop categories:")
            for (i, item) in byCat.sorted(by: { $0.value > $1.value }).prefix(5).enumerated() {
                lines.append("  \(i+1). \(item.key): \(fmt(item.value))")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 11. Savings Opportunities

    @available(iOS 26.0, *)
    func suggestSavings(_ p: SuggestSavingsTool.Arguments) async throws -> String {
        let cal = Calendar.current
        let now = Date()
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now) ?? now

        let txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: threeMonthsAgo, to: now, limit: 10000
        )
        let expenses = txs.filter { $0.type == .gasto }

        var byCat: [String: [Decimal]] = [:]
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "yyyy-MM"
        for tx in expenses {
            let key = "\(tx.category)|\(monthFmt.string(from: tx.date))"
            byCat[tx.category, default: []].append(tx.amount)
        }

        var catAvg: [(String, Decimal)] = []
        for (cat, amounts) in byCat {
            let avg = amounts.reduce(Decimal.zero, +) / 3
            catAvg.append((cat, avg))
        }
        catAvg.sort { $0.1 > $1.1 }

        var lines: [String] = ["Savings Opportunities (based on 3-month average):"]
        lines.append("")

        let targetStr = p.targetSavings.map { fmt(Decimal($0)) } ?? "unspecified"
        lines.append("Target savings: \(targetStr)")
        lines.append("")

        var potentialSavings: Decimal = 0
        let discretionary = Set(["Ocio", "Restaurantes", "Compras", "Suscripciones", "Delivery", "Entretenimiento"])

        for (cat, avg) in catAvg where avg > 0 {
            let suggestion: Decimal
            if discretionary.contains(cat) {
                suggestion = avg * 20 / 100
                lines.append("• \(cat) (avg \(fmt(avg))/mo): reduce 20% → save \(fmt(suggestion))/mo")
            } else {
                suggestion = avg * 10 / 100
                lines.append("• \(cat) (avg \(fmt(avg))/mo): optimize 10% → save \(fmt(suggestion))/mo")
            }
            potentialSavings += suggestion
        }

        lines.append("")
        lines.append("Total potential monthly savings: \(fmt(potentialSavings))")

        if let target = p.targetSavings {
            let targetDec = Decimal(target)
            if potentialSavings >= targetDec {
                lines.append("This exceeds your target of \(fmt(targetDec)).")
            } else {
                lines.append("Gap to target: \(fmt(targetDec - potentialSavings)) — consider additional income sources.")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 12. Goals

    @available(iOS 26.0, *)
    func getGoals(_ p: GetGoalsTool.Arguments) async throws -> String {
        let goals = try await GoalService.shared.fetchAll(
            householdId: householdId, includeCompleted: p.includeCompleted ?? false
        )

        guard !goals.isEmpty else {
            return "No active goals. Create one in More > Goals > + button."
        }

        var lines: [String] = ["Goals (\(goals.count)):"]
        for g in goals {
            let pct = Int(g.progress * 100)
            let remaining = max(0, g.targetAmount - g.currentAmount)
            var line = "• \(g.name): \(fmt(g.currentAmount, cur: g.currency))/\(fmt(g.targetAmount, cur: g.currency)) (\(pct)%)"

            if let target = g.targetDate {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0
                line += " — \(daysLeft) days left"
                if remaining > 0 && daysLeft > 0 {
                    let monthsLeft = max(1, daysLeft / 30)
                    let monthlyNeeded = remaining / Decimal(monthsLeft)
                    line += ", need \(fmt(monthlyNeeded, cur: g.currency))/mo"
                }
            }
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 13. Accounts

    @available(iOS 26.0, *)
    func getAccounts(_ p: GetAccountsTool.Arguments) async throws -> String {
        let accounts = try await AccountService.shared.fetchAll(
            householdId: householdId, includingInactive: p.includeInactive ?? false
        )

        guard !accounts.isEmpty else {
            return "No accounts found. Add one in More > Accounts."
        }

        var lines: [String] = ["Accounts (\(accounts.count)):"]
        for acc in accounts {
            let status = acc.isActive ? "" : " [inactive]"
            let inst = acc.institution.flatMap { $0.isEmpty ? nil : " (\($0))" } ?? ""
            lines.append("• \(acc.name)\(inst): \(acc.type.rawValue) · \(fmt(acc.startingBalance, cur: acc.currency))\(status)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 14. Bills

    @available(iOS 26.0, *)
    func getBills(_ p: GetBillsTool.Arguments) async throws -> String {
        let days = p.daysAhead ?? 30
        let bills = try await BillService.shared.fetchUpcoming(householdId: householdId, daysAhead: days)

        guard !bills.isEmpty else {
            return "No upcoming bills in the next \(days) days."
        }

        var lines: [String] = ["Upcoming Bills (\(bills.count)):"]
        for bill in bills {
            let urgency: String
            switch bill.urgency {
            case .overdue: urgency = "OVERDUE"
            case .dueToday: urgency = "DUE TODAY"
            case .dueSoon: urgency = "Due soon"
            default: urgency = "\(bill.daysUntilDue)d"
            }
            lines.append("• \(bill.title): \(fmt(bill.amount, cur: bill.currency)) — \(fmtDate(bill.dueDate)) [\(urgency)]")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 15. Inflation Impact

    @available(iOS 26.0, *)
    func analyzeInflation(_ p: AnalyzeInflationTool.Arguments) async throws -> String {
        let monthsBack = p.monthsBack ?? 3
        let cal = Calendar.current
        let now = Date()

        let recentStart = cal.date(byAdding: .month, value: -1, to: now) ?? now
        let oldStart = cal.date(byAdding: .month, value: -(monthsBack + 1), to: now) ?? now
        let oldEnd = cal.date(byAdding: .month, value: -monthsBack, to: now) ?? now

        let recentTxs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: recentStart, to: now, limit: 5000
        )
        let oldTxs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: oldStart, to: oldEnd, limit: 5000
        )

        let recentExp = recentTxs.filter { $0.type == .gasto }
        let oldExp = oldTxs.filter { $0.type == .gasto }

        func aggregate(_ txs: [Transaction]) -> [String: (total: Decimal, count: Int)] {
            var result: [String: (total: Decimal, count: Int)] = [:]
            for tx in txs {
                let cat = p.category.flatMap { tx.category.lowercased().contains($0.lowercased()) ? tx.category : nil } ?? tx.category
                if p.category != nil && cat != tx.category { continue }
                let existing = result[tx.category] ?? (0, 0)
                result[tx.category] = (existing.total + tx.amount, existing.count + 1)
            }
            return result
        }

        let recent = aggregate(recentExp)
        let old = aggregate(oldExp)

        var lines: [String] = ["Inflation & Price Impact Analysis (\(monthsBack) months ago vs now):"]
        lines.append("")

        let recentTotal = recentExp.reduce(Decimal.zero) { $0 + $1.amount }
        let oldTotal = oldExp.reduce(Decimal.zero) { $0 + $1.amount }

        if oldTotal > 0 {
            let totalChange = ((recentTotal - oldTotal) / oldTotal) as NSDecimalNumber
            lines.append("Overall spending change: \(Int(totalChange.doubleValue * 100))%")
        }
        lines.append("")

        for (cat, r) in recent.sorted(by: { $0.value.total > $1.value.total }) {
            guard let o = old[cat], o.total > 0 else { continue }
            let totalChange = ((r.total - o.total) / o.total) as NSDecimalNumber
            let avgRecent: Decimal = r.count > 0 ? r.total / Decimal(r.count) : 0
            let avgOld: Decimal = o.count > 0 ? o.total / Decimal(o.count) : 0

            var line = "• \(cat): \(Int(totalChange.doubleValue * 100))% change"

            if avgOld > 0 {
                let priceChange = ((avgRecent - avgOld) / avgOld) as NSDecimalNumber
                let qtyChange = r.count - o.count
                line += " (avg price \(Int(priceChange.doubleValue * 100))%"
                if qtyChange != 0 {
                    line += ", qty \(qtyChange > 0 ? "+" : "")\(qtyChange)"
                }
                line += ")"
            }
            lines.append(line)
        }

        lines.append("")
        lines.append("Note: This compares your actual spending, not official inflation indexes. Price changes are approximated from average transaction amounts.")

        return lines.joined(separator: "\n")
    }
    #endif

    // MARK: - 16. Mark Bill Paid

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    func markBillPaid(_ p: MarkBillPaidTool.Arguments) async throws -> String {
        guard let uuid = UUID(uuidString: p.billId) else {
            return "Error: billId no es un UUID válido"
        }
        do {
            try await BillService.shared.markPaid(id: uuid)
            return "✅ Factura marcada como pagada."
        } catch {
            return "Error al marcar la factura: \(error.localizedDescription)"
        }
    }
    #endif

    // MARK: - 17. Compare Periods

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    func comparePeriods(_ p: ComparePeriodsTool.Arguments) async throws -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        guard let dateA = fmt.date(from: p.periodA),
              let dateB = fmt.date(from: p.periodB) else {
            return "Error: períodos deben estar en formato yyyy-MM (ej: 2026-04)"
        }

        func rangeFor(_ d: Date) -> (Date, Date) {
            let comps = cal.dateComponents([.year, .month], from: d)
            let start = cal.date(from: comps) ?? d
            let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? d
            return (start, end)
        }

        let (startA, endA) = rangeFor(dateA)
        let (startB, endB) = rangeFor(dateB)

        async let totalsA = TransactionService.shared.totals(householdId: householdId, from: startA, to: endA)
        async let totalsB = TransactionService.shared.totals(householdId: householdId, from: startB, to: endB)
        async let txA = TransactionService.shared.fetchForPeriod(householdId: householdId, from: startA, to: endA, limit: 5000)
        async let txB = TransactionService.shared.fetchForPeriod(householdId: householdId, from: startB, to: endB, limit: 5000)

        let (tA, tB) = try await (totalsA, totalsB)
        let (allA, allB) = try await (txA, txB)

        // Compute top categories inline (no dedicated service method exists).
        func topCategories(_ txs: [Transaction]) -> [(category: String, total: Decimal)] {
            var sums: [String: Decimal] = [:]
            for t in txs where t.type == .gasto {
                sums[t.category, default: 0] += t.amount
            }
            return sums.map { ($0.key, $0.value) }
                .sorted { $0.1 > $1.1 }
                .prefix(5)
                .map { ($0.0, $0.1) }
        }
        let catsA = topCategories(allA)
        let catsB = topCategories(allB)

        let balA = tA.ingresos - tA.gastos
        let balB = tB.ingresos - tB.gastos
        let svgRateA: Int = tA.ingresos > 0 ? Int(((balA / tA.ingresos) as NSDecimalNumber).doubleValue * 100) : 0
        let svgRateB: Int = tB.ingresos > 0 ? Int(((balB / tB.ingresos) as NSDecimalNumber).doubleValue * 100) : 0

        let deltaIng = tA.ingresos - tB.ingresos
        let deltaGas = tA.gastos - tB.gastos
        let deltaBal = balA - balB

        func fmtAmount(_ d: Decimal) -> String {
            Money.format(d, currency: currency, style: .compact)
        }
        func fmtDelta(_ d: Decimal) -> String {
            let sign = d >= 0 ? "+" : ""
            return "\(sign)\(fmtAmount(d))"
        }

        var lines: [String] = []
        lines.append("\(p.periodA) vs \(p.periodB) (\(currency)):")
        lines.append("• Ingresos: \(fmtAmount(tA.ingresos)) vs \(fmtAmount(tB.ingresos)) — Δ \(fmtDelta(deltaIng))")
        lines.append("• Gastos: \(fmtAmount(tA.gastos)) vs \(fmtAmount(tB.gastos)) — Δ \(fmtDelta(deltaGas))")
        lines.append("• Balance: \(fmtAmount(balA)) vs \(fmtAmount(balB)) — Δ \(fmtDelta(deltaBal))")
        lines.append("• Savings rate: \(svgRateA)% vs \(svgRateB)%")

        if !catsA.isEmpty {
            lines.append("")
            lines.append("Top categorías \(p.periodA):")
            for (i, c) in catsA.prefix(5).enumerated() {
                lines.append("  \(i+1). \(c.category): \(fmtAmount(c.total))")
            }
        }
        if !catsB.isEmpty {
            lines.append("")
            lines.append("Top categorías \(p.periodB):")
            for (i, c) in catsB.prefix(5).enumerated() {
                lines.append("  \(i+1). \(c.category): \(fmtAmount(c.total))")
            }
        }

        return lines.joined(separator: "\n")
    }
    #endif

    // MARK: - 18. Set Budget Envelope

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    func setBudgetEnvelope(_ p: SetBudgetEnvelopeTool.Arguments) async throws -> String {
        guard p.amount >= 0 else {
            return "Error: el monto debe ser >= 0"
        }
        let cal = Calendar.current
        let date: Date = {
            if let m = p.month {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM"
                fmt.locale = Locale(identifier: "en_US_POSIX")
                return fmt.date(from: m) ?? Date()
            }
            return Date()
        }()
        do {
            let period = try await BudgetService.shared.ensurePeriodForMonth(
                householdId: householdId, containing: date
            )
            _ = try await BudgetService.shared.upsertAllocation(
                periodId: period.id,
                category: p.category,
                subcategory: p.subcategory ?? "",
                allocated: Decimal(p.amount),
                currency: currency
            )
            let formatted = Money.format(Decimal(p.amount), currency: currency, style: .compact)
            let sub = (p.subcategory?.isEmpty == false) ? " > \(p.subcategory!)" : ""
            let monthFmt = DateFormatter()
            monthFmt.dateFormat = "yyyy-MM"
            monthFmt.locale = Locale(identifier: "en_US_POSIX")
            let periodLabel = monthFmt.string(from: period.periodStart)
            return "✅ Presupuesto seteado: \(p.category)\(sub) = \(formatted) para \(periodLabel)."
        } catch {
            return "Error al setear presupuesto: \(error.localizedDescription)"
        }
        _ = cal
    }
    #endif

    // MARK: - 19. Transfer Between Accounts

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    func transferBetweenAccounts(_ p: TransferBetweenAccountsTool.Arguments) async throws -> String {
        guard p.amount > 0 else {
            return "Error: el monto debe ser mayor a cero"
        }
        guard let fromId = UUID(uuidString: p.fromAccountId),
              let toId = UUID(uuidString: p.toAccountId) else {
            return "Error: account IDs deben ser UUIDs validos"
        }
        guard fromId != toId else {
            return "Error: la cuenta origen y destino no pueden ser la misma"
        }
        let amount = Decimal(p.amount)
        let now = Date()
        let baseNote = p.note?.isEmpty == false ? p.note! : "Transferencia entre cuentas"

        // Leg 1: gasto en cuenta origen
        let expense = NewTransactionInput(
            householdId: householdId,
            userId: userId,
            accountId: fromId,
            type: .gasto,
            amount: amount,
            currencyOriginal: nil,
            category: "Transferencia",
            subcategory: nil,
            note: "→ \(baseNote)",
            date: now
        )
        // Leg 2: ingreso en cuenta destino
        let income = NewTransactionInput(
            householdId: householdId,
            userId: userId,
            accountId: toId,
            type: .ingreso,
            amount: amount,
            currencyOriginal: nil,
            category: "Transferencia",
            subcategory: nil,
            note: "← \(baseNote)",
            date: now
        )

        do {
            _ = try await TransactionService.shared.insert(expense)
            _ = try await TransactionService.shared.insert(income)
            let formatted = Money.format(amount, currency: currency, style: .compact)
            return "✅ Transferencia ejecutada: \(formatted) movido entre cuentas. Se crearon 2 transacciones linkeadas."
        } catch {
            return "Error en la transferencia: \(error.localizedDescription). Si solo se ejecuto la primera pierna, hace falta corregir manualmente desde Movimientos."
        }
    }
    #endif

    // MARK: - 20. Categorize Transaction

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    func categorizeTransaction(_ p: CategorizeTransactionTool.Arguments) async throws -> String {
        let text = p.text.lowercased()
        guard !text.isEmpty else {
            return "Error: necesito un texto descriptivo para categorizar"
        }

        // Heuristica determinista basada en keywords LATAM-friendly.
        // No requiere red — es rapida y no consume tokens del LLM.
        let patterns: [(category: String, keywords: [String], confidence: Double)] = [
            ("Alimentacion", ["super", "mercado", "verduleria", "carniceria", "panaderia", "almacen", "coto", "carrefour", "dia", "jumbo", "disco"], 0.92),
            ("Restaurantes", ["restaurante", "bar", "cafe", "rappi", "pedidos ya", "uber eats", "delivery", "pizza", "sushi"], 0.90),
            ("Transporte", ["uber", "cabify", "didi", "taxi", "subte", "colectivo", "tren", "ypf", "axion", "shell", "nafta", "combustible", "estacionamiento", "peaje"], 0.92),
            ("Servicios", ["luz", "edenor", "edesur", "metrogas", "gas", "agua", "aysa", "internet", "fibertel", "telecentro", "movistar", "claro", "personal", "telecom"], 0.94),
            ("Streaming", ["netflix", "spotify", "disney", "hbo", "amazon prime", "apple music", "youtube premium"], 0.95),
            ("Salud", ["farmacia", "farmacity", "doctor", "clinica", "hospital", "obra social", "osde", "swiss medical"], 0.92),
            ("Entretenimiento", ["cine", "teatro", "concierto", "show", "boleto"], 0.85),
            ("Hogar", ["sodimac", "easy", "ikea", "ferreteria", "mueble", "limpieza"], 0.85),
            ("Educacion", ["universidad", "curso", "udemy", "coursera", "libreria", "libro"], 0.88),
            ("Ropa", ["zara", "h&m", "indumentaria", "ropa", "calzado"], 0.85),
            ("Sueldo", ["sueldo", "salario", "haberes", "pago mensual"], 0.96),
            ("Freelance", ["freelance", "honorarios", "factura"], 0.85),
        ]

        var best: (String, Double) = ("Otro", 0.3)
        for p in patterns {
            for kw in p.keywords {
                if text.contains(kw) && p.confidence > best.1 {
                    best = (p.category, p.confidence)
                }
            }
        }

        return "Sugerencia: \(best.0) (confianza \(String(format: "%.0f", best.1 * 100))%). Si no es correcto, indicame la categoria correcta."
    }
    #endif

    // MARK: - Helpers

    private func expandUUID(_ s: String) -> String {
        if s.count == 8 { return s }
        return s
    }
}
