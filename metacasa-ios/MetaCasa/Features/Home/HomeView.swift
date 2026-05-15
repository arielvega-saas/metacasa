import SwiftUI
import Observation
import Charts

/// Dashboard premium (rewrite 2026-04-20 Sprint 3+).
///
/// Diseño inspirado en la generación de apps de finanzas tipo Monarch /
/// Copilot / YNAB mobile — usa materiales iOS nativos, progress rings
/// watchOS-style, Swift Charts, haptics + animaciones al cargar y al
/// interactuar, y fixes de layout que evitan que los montos grandes se
/// corten en pantallas chicas.
///
/// Widgets (orden vertical):
///   1. HeroBalanceCard — card grande con gradient, delta vs mes pasado
///   2. StatsRow — ingresos + gastos (2 tiles con sparkline)
///   3. InsightCard — insight "del asistente" accionable
///   4. ReadyToAssignCard — saldo por asignar del envelope
///   5. UpcomingBillsStrip — timeline horizontal de vencimientos
///   6. GoalsRingsRow — scroll horizontal de progress rings
///   7. CategoryDonutCard — donut chart + lista top 5 gastos
///   8. QuickShortcutsCarousel — atajos de transacción
///   9. DebtsAndPlansTiles — deudas y cuotas
@MainActor
@Observable
final class HomeViewModel {
    var totalIngresos: Decimal = 0
    var totalGastos: Decimal = 0
    var topGastos: [Transaction] = []
    var period: BudgetPeriod?
    var upcomingBills: [Bill] = []
    var activeDebtsCount: Int = 0
    var activePlansCount: Int = 0
    var monthlyDebtCommitment: Decimal = 0

    var activeGoals: [Goal] = []
    var prevMonthIngresos: Decimal = 0
    var prevMonthGastos: Decimal = 0
    var topCategories: [(category: String, total: Decimal)] = []
    var templates: [TransactionTemplate] = []
    var recentTransactions: [Transaction] = []

    /// Patrimonio neto del hogar computado con `AccountBalanceService`.
    /// Assets - Liabilities. Usa ventana de 365 días de transacciones para
    /// running balance — suficiente para la mayoría de cuentas activas.
    var netWorth: NetWorthBreakdown = .zero

    var isLoading = false
    var errorMessage: String?
    var hasLoadedOnce = false

    var balance: Decimal { totalIngresos - totalGastos }
    var balancePrev: Decimal { prevMonthIngresos - prevMonthGastos }

    /// Health Score 0-100 ponderando savings rate (50%), expense-to-income ratio (30%)
    /// y consistencia/streak (20%). Misma fórmula que ReportsView pero sobre el mes.
    var healthScore: Int {
        var score: Double = 0
        if totalIngresos > 0 {
            let rate = max(0, (totalIngresos - totalGastos) / totalIngresos)
            score += min(50, (rate as NSDecimalNumber).doubleValue * 250)
            let ratio = (totalGastos as NSDecimalNumber).doubleValue / (totalIngresos as NSDecimalNumber).doubleValue
            if ratio < 1.0 {
                score += (1.0 - ratio) * 30
            }
        }
        let cal = Calendar.current
        let last30 = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let daysWithTx = Set(recentTransactions.filter { $0.date >= last30 }.map { cal.startOfDay(for: $0.date) }).count
        score += min(20, Double(daysWithTx) * 0.67)
        return max(0, min(100, Int(score)))
    }

    /// Racha de días consecutivos (contando hacia atrás desde hoy) con al
    /// menos una transacción cargada. Usado en el widget 🔥 del Home.
    var streak: Int {
        let cal = Calendar.current
        var days = Set(recentTransactions.map { cal.startOfDay(for: $0.date) })
        // Fallback: si recentTransactions tiene <1 mes de data pero el user
        // carga hoy, contamos desde hoy. Esto funciona porque siempre hay al
        // menos la ventana del mes en recentTransactions.
        var count = 0
        var cursor = cal.startOfDay(for: Date())
        while days.contains(cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
            _ = days.remove(prev) // asegura que el set se achique para evitar loops sobre gaps
        }
        return count
    }

    /// Sparkline: últimos 7 días de gastos acumulados.
    var expenseSparkline: [Decimal] {
        let cal = Calendar.current
        let now = Date()
        var daily: [Decimal] = Array(repeating: 0, count: 7)
        for tx in recentTransactions where tx.type == .gasto {
            let days = cal.dateComponents([.day], from: tx.date, to: now).day ?? 99
            if days >= 0 && days < 7 {
                daily[6 - days] += tx.amount
            }
        }
        return daily
    }

    /// Sparkline: últimos 7 días de ingresos.
    var incomeSparkline: [Decimal] {
        let cal = Calendar.current
        let now = Date()
        var daily: [Decimal] = Array(repeating: 0, count: 7)
        for tx in recentTransactions where tx.type == .ingreso {
            let days = cal.dateComponents([.day], from: tx.date, to: now).day ?? 99
            if days >= 0 && days < 7 {
                daily[6 - days] += tx.amount
            }
        }
        return daily
    }

    func load(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        do {
            let now = Date()
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: now)
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59), to: start),
                  let prevStart = cal.date(byAdding: .month, value: -1, to: start),
                  let prevEnd = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59), to: prevStart)
            else { return }

            async let totals = TransactionService.shared.totals(householdId: householdId, from: start, to: end)
            async let prevTotals = TransactionService.shared.totals(householdId: householdId, from: prevStart, to: prevEnd)
            async let transactions = TransactionService.shared.fetchForPeriod(householdId: householdId, from: start, to: end, limit: 500)
            async let budgetPeriod = BudgetService.shared.fetchPeriod(householdId: householdId, containing: now)
            async let bills = BillService.shared.fetchUpcoming(householdId: householdId, daysAhead: 14)
            async let debts = DebtService.shared.fetchAll(householdId: householdId, includeSettled: false)
            async let plans = InstallmentService.shared.fetchPlans(householdId: householdId, includeCompleted: false)
            async let goals = GoalService.shared.fetchAll(householdId: householdId, includeCompleted: false)
            async let templatesTask = TemplateService.shared.fetchAll(householdId: householdId)
            // Net worth: necesitamos accounts + txs de ~12 meses para running balance.
            let yearAgo = cal.date(byAdding: .day, value: -365, to: now) ?? now
            async let accountsTask = AccountService.shared.fetchAll(householdId: householdId, includingInactive: false)
            async let yearTxsTask = TransactionService.shared.fetchForPeriod(
                householdId: householdId, from: yearAgo, to: now, limit: 10_000
            )

            let t = try await totals
            self.totalIngresos = t.ingresos
            self.totalGastos = t.gastos

            let p: (ingresos: Decimal, gastos: Decimal) = (try? await prevTotals) ?? (ingresos: 0, gastos: 0)
            self.prevMonthIngresos = p.ingresos
            self.prevMonthGastos = p.gastos

            let txs = try await transactions
            self.recentTransactions = txs
            self.topGastos = Array(txs.filter { $0.type == .gasto }.sorted { $0.amount > $1.amount }.prefix(5))

            var byCat: [String: Decimal] = [:]
            for tx in txs where tx.type == .gasto {
                byCat[tx.category, default: 0] += tx.amount
            }
            self.topCategories = byCat.sorted { $0.value > $1.value }.prefix(5)
                .map { (category: $0.key, total: $0.value) }

            self.period = try await budgetPeriod
            self.upcomingBills = (try? await bills) ?? []
            let dbList = (try? await debts) ?? []
            self.activeDebtsCount = dbList.count
            self.monthlyDebtCommitment = dbList.compactMap { $0.monthlyPayment }.reduce(Decimal(0), +)
            self.activePlansCount = (try? await plans)?.count ?? 0
            self.activeGoals = (try? await goals) ?? []
            self.templates = (try? await templatesTask) ?? []

            // Net worth final: ya tengo accounts, yearTxs y debts. Computo en memoria.
            let accounts = (try? await accountsTask) ?? []
            let yearTxs = (try? await yearTxsTask) ?? []
            self.netWorth = AccountBalanceService.netWorth(
                accounts: accounts,
                transactions: yearTxs,
                debts: dbList
            )

            // Live Activity: si hay un bill en <48h, iniciamos/actualizamos la
            // activity en Lock Screen / Dynamic Island. No-op si no está el
            // Widget target (requiere Apple Developer Team ID para completar).
            if #available(iOS 16.1, *) {
                let currency = appStateCurrencyFallback()
                Task { @MainActor in
                    await LiveActivityService.startOrUpdateNextBillActivity(
                        bills: self.upcomingBills,
                        currency: currency
                    )
                }
            }

            // Spotlight: re-indexar transacciones + metas activas del hogar
            // en el índice del sistema. Low priority task (no bloquea UI).
            let indexTxs = txs                    // month txs (captured)
            let indexGoals = self.activeGoals
            let indexCurrency = appStateCurrencyFallback()
            Task.detached(priority: .utility) {
                await SpotlightIndexer.reindex(
                    transactions: indexTxs,
                    goals: indexGoals,
                    currency: indexCurrency
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moneda de fallback sin acceso directo a AppState (no lo tenemos en el
    /// ViewModel). En producción la Live Activity recibe la moneda correcta
    /// desde el HomeView (que sí lo tiene). Por ahora devolvemos "USD" — el
    /// HomeView podría pasarla cuando llamemos via API pública. Marcado como
    /// punto de extensión.
    private func appStateCurrencyFallback() -> String { "USD" }

    /// Escribe el snapshot al App Group para que lo lea el Widget. No-op si
    /// el App Group no está configurado (ej. build sin Widget target).
    func syncWidgetSnapshot(householdName: String, currency: String) {
        WidgetSnapshotSync.writeLatest(
            householdName: householdName,
            currency: currency,
            balance: balance,
            ingresos: totalIngresos,
            gastos: totalGastos,
            nextBill: upcomingBills.first
        )
    }
}

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(PrivacyManager.self) private var privacy
    @Environment(DashboardPreferences.self) private var dashboardPrefs
    @Environment(OnboardingProgress.self) private var onboarding
    @State private var viewModel = HomeViewModel()
    @State private var showCompare = false
    @State private var showAnnual = false
    @State private var showStrategySettings = false
    @State private var showDashboardEditor = false
    /// Cuando el user toca Saldo / Ingresos / Gastos, presentamos el
    /// desglose (composición del importe) — estilo Mercado Pago.
    @State private var breakdownMode: BalanceBreakdownMode?
    // PDF share del mes — se genera on-demand y luego se abre el share sheet.
    @State private var isBuildingPDF = false
    @State private var pendingPDFURL: URL?
    @State private var showPDFShare = false
    @State private var pdfBuildError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                ScrollView {
                    VStack(spacing: 18) {
                        if onboarding.shouldShow {
                            SetupChecklistCard()
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }
                        // Widgets respetan orden definido por el user en el Dashboard Editor.
                        // Cada widget es render-eado por `widgetView(for:)` más abajo —
                        // ese @ViewBuilder conoce los params de cada uno desde viewModel.
                        ForEach(dashboardPrefs.orderedVisibleWidgets, id: \.self) { widget in
                            widgetView(for: widget)
                        }
                        if let msg = viewModel.errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120) // espacio para FAB asistente
                }
                .refreshable {
                    Haptics.play(.impactLight)
                    await reload()
                }
            }
            .navigationTitle(householdName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(
                            item: monthlySummaryText,
                            subject: Text("home.shareSubject \(householdName)"),
                            message: Text("home.shareMessage")
                        ) {
                            Label("home.shareSummary", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            Task { await buildAndShareMonthPDF() }
                        } label: {
                            if isBuildingPDF {
                                Label("home.sharePDF.building", systemImage: "hourglass")
                            } else {
                                Label("home.sharePDF", systemImage: "doc.richtext")
                            }
                        }
                        .disabled(isBuildingPDF)
                        Button {
                            showDashboardEditor = true
                        } label: {
                            Label("dashboard.editor.open", systemImage: "square.grid.2x2")
                        }
                    } label: {
                        if isBuildingPDF {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.brandPrimary)
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .task { await reload() }
            .sheet(isPresented: $showCompare) { CompareMonthsView() }
            .sheet(isPresented: $showAnnual) { AnnualView() }
            .sheet(item: $breakdownMode) { mode in
                BalanceBreakdownView(
                    mode: mode,
                    transactions: viewModel.recentTransactions,
                    ingresos: viewModel.totalIngresos,
                    gastos: viewModel.totalGastos,
                    currency: householdCurrency
                )
            }
            .sheet(isPresented: $showStrategySettings) {
                PlanEditorView(
                    strategy: currentStrategy,
                    onSave: { newStrategy in
                        Task { await saveStrategy(newStrategy) }
                    }
                )
            }
            .sheet(isPresented: $showDashboardEditor) {
                DashboardEditorSheet()
            }
            .sheet(isPresented: $showPDFShare) {
                if let url = pendingPDFURL {
                    MonthPDFSharePreview(
                        url: url,
                        householdName: householdName
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .alert(
                Text("home.sharePDF.error.title"),
                isPresented: Binding(
                    get: { pdfBuildError != nil },
                    set: { if !$0 { pdfBuildError = nil } }
                )
            ) {
                Button("action.close", role: .cancel) { pdfBuildError = nil }
            } message: {
                Text(pdfBuildError ?? "")
            }
        }
    }

    /// Genera un PDF del mes actual (paridad con el web ReportModal) y
    /// presenta el `MonthPDFSharePreview` con ShareLink nativo al terminar.
    @MainActor
    private func buildAndShareMonthPDF() async {
        guard let hid = appState.currentHouseholdId else { return }
        let household = appState.households.first(where: { $0.id == hid })
        let householdName = household?.name ?? "Hogar"
        let currency = household?.defaultCurrency ?? "USD"

        // Rango: mes actual (primer día 00:00 → último día 23:59).
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: now)
        guard
            let start = cal.date(from: comps),
            let end = cal.date(
                byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59, second: 59),
                to: start
            )
        else { return }

        isBuildingPDF = true
        defer { isBuildingPDF = false }

        do {
            let txs = try await TransactionService.shared.fetchForPeriod(
                householdId: hid,
                from: start,
                to: end,
                limit: 10_000
            )
            let doc = try TransactionPDFExporter.export(
                transactions: txs,
                householdName: householdName,
                householdCurrency: currency,
                dateRange: (from: start, to: end),
                locale: AppLocaleStorage.effectiveLocale
            )
            pendingPDFURL = doc.url
            showPDFShare = true
            Haptics.play(.success)
        } catch {
            pdfBuildError = error.localizedDescription
            Haptics.play(.error)
        }
    }

    /// Dispatcher de widgets del Home según el `order` del user. Cada case
    /// instancia el component correspondiente con los params del viewModel.
    /// Si se agrega un nuevo `DashboardWidgetID`, hay que agregar su case acá.
    @ViewBuilder
    private func widgetView(for widget: DashboardWidgetID) -> some View {
        switch widget {
        case .hero:
            HeroBalanceCard(
                balance: viewModel.balance,
                prevBalance: viewModel.balancePrev,
                currency: householdCurrency,
                isLoading: viewModel.isLoading && !viewModel.hasLoadedOnce,
                isHidden: privacy.isEnabled,
                onToggleHide: {
                    Haptics.play(.impactLight)
                    privacy.toggle()
                },
                onCompareTap: { showCompare = true },
                onAnnualTap: { showAnnual = true },
                onTap: {
                    Haptics.play(.selection)
                    breakdownMode = .balance
                }
            )
        case .stats:
            StatsRow(
                ingresos: viewModel.totalIngresos,
                gastos: viewModel.totalGastos,
                incomeSpark: viewModel.incomeSparkline,
                expenseSpark: viewModel.expenseSparkline,
                currency: householdCurrency,
                onTap: { mode in
                    Haptics.play(.selection)
                    breakdownMode = mode
                }
            )
        case .insight:
            InsightCard(viewModel: viewModel, currency: householdCurrency)
        case .health:
            HealthScoreCard(score: viewModel.healthScore, streak: viewModel.streak)
        case .netWorth:
            NetWorthCard(
                breakdown: viewModel.netWorth,
                currency: householdCurrency,
                isHidden: privacy.isEnabled
            )
        case .savingsInvestment:
            SavingsInvestmentCard(
                ingresos: viewModel.totalIngresos,
                strategy: currentStrategy,
                currency: householdCurrency,
                onConfigureTap: { showStrategySettings = true }
            )
        case .readyToAssign:
            ReadyToAssignCard(period: viewModel.period, currency: householdCurrency)
        case .upcomingBills:
            UpcomingBillsStrip(bills: viewModel.upcomingBills, currency: householdCurrency)
        case .goals:
            GoalsRingsRow(goals: viewModel.activeGoals)
        case .categories:
            CategoryDonutCard(items: viewModel.topCategories, currency: householdCurrency)
        case .shortcuts:
            QuickShortcutsCarousel(templates: viewModel.templates)
        case .debts:
            DebtsAndPlansTiles(
                debtsCount: viewModel.activeDebtsCount,
                plansCount: viewModel.activePlansCount,
                monthlyDebtCommitment: viewModel.monthlyDebtCommitment,
                currency: householdCurrency
            )
        }
    }

    private var currentStrategy: HouseholdStrategy {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.strategy ?? .default
    }

    @MainActor
    private func saveStrategy(_ newStrategy: HouseholdStrategy) async {
        guard let hid = appState.currentHouseholdId else { return }
        do {
            _ = try await HouseholdService.shared.updateStrategy(householdId: hid, strategy: newStrategy)
            try await appState.loadHouseholds()
            Haptics.play(.success)
        } catch {
            viewModel.errorMessage = error.localizedDescription
            Haptics.play(.error)
        }
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }
    private var householdName: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.name ?? "Hogar"
    }

    /// Resumen del mes como texto plano para compartir via ShareLink.
    /// Se regenera cada vez que cambia el view model (reactivo).
    private var monthlySummaryText: String {
        let df = DateFormatter()
        df.locale = AppLocaleStorage.effectiveLocale
        df.dateFormat = "LLLL yyyy"
        let period = df.string(from: Date()).capitalized

        var lines: [String] = []
        lines.append("📊 \(householdName) — \(period)")
        lines.append("")
        lines.append("💰 \(String(localized: "budget.income")): \(Money.format(viewModel.totalIngresos, currency: householdCurrency, style: .auto))")
        lines.append("💸 \(String(localized: "budget.spent")): \(Money.format(viewModel.totalGastos, currency: householdCurrency, style: .auto))")
        let balanceEmoji = viewModel.balance >= 0 ? "📈" : "📉"
        lines.append("\(balanceEmoji) \(String(localized: "home.balance.month")): \(Money.format(viewModel.balance, currency: householdCurrency, style: .auto))")
        lines.append("")
        if !viewModel.topCategories.isEmpty {
            lines.append(String(localized: "home.share.topCategories"))
            for (i, item) in viewModel.topCategories.prefix(3).enumerated() {
                let pct = viewModel.totalGastos > 0
                    ? Int(((item.total / viewModel.totalGastos) as NSDecimalNumber).doubleValue * 100)
                    : 0
                lines.append("\(i + 1). \(CategoryCatalog.emoji(for: item.category)) \(item.category): \(Money.format(item.total, currency: householdCurrency, style: .compact)) · \(pct)%")
            }
            lines.append("")
        }
        lines.append("❤️ Health Score: \(viewModel.healthScore)/100")
        if viewModel.streak > 0 {
            lines.append(String(format: String(localized: "home.share.streak %d"), viewModel.streak))
        }
        lines.append("")
        lines.append(String(localized: "home.share.footer"))
        return lines.joined(separator: "\n")
    }

    private var backgroundGradient: some View {
        // Midnight Sage: fondo sutil con radial sage en esquina para dar
        // profundidad sin saturar — zen/spa nocturno.
        ZStack {
            Color.appBackground
            RadialGradient(
                colors: [Color.brandPrimary.opacity(0.06), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    private func reload() async {
        if let hid = appState.currentHouseholdId {
            await viewModel.load(householdId: hid)
            viewModel.syncWidgetSnapshot(
                householdName: householdName,
                currency: householdCurrency
            )
            // Refresh del onboarding en paralelo — el user puede haber
            // completado un step fuera de la app (ej: agregó cuenta desde tab).
            await onboarding.refresh(appState: appState)
        }
    }
}

// MARK: - HeroBalanceCard

private struct HeroBalanceCard: View {
    let balance: Decimal
    let prevBalance: Decimal
    let currency: String
    let isLoading: Bool
    let isHidden: Bool
    let onToggleHide: () -> Void
    let onCompareTap: () -> Void
    let onAnnualTap: () -> Void
    var onTap: () -> Void = {}

    private var delta: Decimal { balance - prevBalance }
    private var improved: Bool { delta >= 0 }
    private var deltaPct: Double {
        guard prevBalance != 0 else { return 0 }
        let d = (delta as NSDecimalNumber).doubleValue
        let p = abs((prevBalance as NSDecimalNumber).doubleValue)
        return p > 0 ? (d / p) * 100 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label {
                    Text("home.balance.month").font(.mcLabel)
                } icon: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.3), isActive: isLoading)
                }
                .foregroundStyle(Color.textMuted)
                Spacer()
                HStack(spacing: 10) {
                    // Ojo: toggle para ocultar/mostrar montos (paridad con apps de billeteras).
                    compactChip(
                        icon: isHidden ? "eye.slash.fill" : "eye.fill",
                        action: onToggleHide,
                        highlighted: isHidden
                    )
                    compactChip(icon: "arrow.left.arrow.right.square", action: onCompareTap)
                    compactChip(icon: "calendar", action: onAnnualTap)
                }
            }

            // Balance hero en serif — Midnight Sage typography.
            // Usamos .neutro (cream/textPrimary) en vez de .balance para que el
            // número grande sea neutro editorial; la tendencia (chip debajo)
            // indica signo.
            AmountLabel(amount: balance, currency: currency, kind: .neutro)
                .font(.mcSerifHero)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text("a11y.home.balance.label"))
                .accessibilityValue(Text(isHidden ? String(localized: "a11y.hidden") : Money.format(balance, currency: currency, style: .auto)))
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                Image(systemName: improved ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundStyle(improved ? Color.brandSuccess : Color.brandDanger)
                    .font(.headline)
                Text(deltaText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(improved ? Color.brandSuccess : Color.brandDanger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            // Borde fino luminoso sage — característica Midnight Sage.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.brandPrimary.opacity(0.15), lineWidth: 1)
        )
        // Toda la card es tappable → desglose. Los chips internos (ojo,
        // comparar, anual) son Buttons y SwiftUI les da prioridad, así
        // que siguen funcionando sin disparar el desglose.
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var deltaText: String {
        let amtStr = isHidden ? "•••" : Money.format(abs(delta), currency: currency, style: .compact)
        if prevBalance == 0 {
            return improved ? "+\(amtStr) vs mes anterior" : "\(amtStr) vs mes anterior"
        }
        let pctStr = String(format: "%+.0f%%", deltaPct)
        return "\(improved ? "+" : "-")\(amtStr) · \(pctStr)"
    }

    private func compactChip(icon: String, action: @escaping () -> Void, highlighted: Bool = false) -> some View {
        Button {
            Haptics.play(.selection)
            action()
        } label: {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(highlighted ? Color.brandPrimary : Color.textPrimary)
                .frame(width: 32, height: 32)
                .background(highlighted ? Color.brandPrimary.opacity(0.2) : Color.white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(chipAccessibilityLabel(for: icon)))
    }

    /// VoiceOver labels para los chips del hero: compact description de la
    /// acción que dispara cada botón (ocultar monto, comparar meses, ver anual).
    private func chipAccessibilityLabel(for icon: String) -> LocalizedStringKey {
        switch icon {
        case "eye.fill":        return "a11y.home.hideAmounts"
        case "eye.slash.fill":  return "a11y.home.showAmounts"
        case "arrow.left.arrow.right.square": return "a11y.home.compareMonths"
        case "calendar":        return "a11y.home.annualView"
        default:                return "a11y.button.generic"
        }
    }
}

// MARK: - SavingsInvestmentCard

/// Widget que muestra ahorro + inversión calculado a partir del porcentaje
/// configurado en la estrategia del hogar. Paridad con la UX de la app web.
/// Tap → abre sheet de configuración.
private struct SavingsInvestmentCard: View {
    let ingresos: Decimal
    let strategy: HouseholdStrategy
    let currency: String
    let onConfigureTap: () -> Void

    private var savingsAmount: Decimal {
        ingresos * strategy.savingsPct / 100
    }
    private var investmentAmount: Decimal {
        ingresos * strategy.investmentPct / 100
    }
    private var totalAllocation: Decimal {
        savingsAmount + investmentAmount
    }
    private var savingsPct: Int { Int((strategy.savingsPct as NSDecimalNumber).doubleValue) }
    private var investmentPct: Int { Int((strategy.investmentPct as NSDecimalNumber).doubleValue) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label {
                    Text("home.savings.title").font(.mcH2)
                } icon: {
                    Image(systemName: "banknote.fill")
                        .foregroundStyle(Color.brandSuccess)
                }
                .foregroundStyle(Color.textPrimary)
                Spacer()
                Button {
                    Haptics.play(.selection)
                    onConfigureTap()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.brandPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.brandPrimary.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if ingresos <= 0 {
                // Estado vacío — sin ingresos no hay base para calcular.
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.textMuted)
                    Text("home.savings.empty")
                        .font(.caption)
                        .foregroundStyle(Color.textMuted)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurfaceInset)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 12) {
                    percentTile(
                        icon: "banknote.fill",
                        labelKey: "home.savings.savings",
                        pct: savingsPct,
                        amount: savingsAmount,
                        color: .brandSuccess
                    )
                    percentTile(
                        icon: "chart.line.uptrend.xyaxis.circle.fill",
                        labelKey: "home.savings.investment",
                        pct: investmentPct,
                        amount: investmentAmount,
                        color: .brandPrimary
                    )
                }

                // Barra visual con proporción ahorro/inversión del ingreso total
                allocationBar
            }

            // CTA profesional
            Button {
                Haptics.play(.impactMedium)
                onConfigureTap()
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("home.savings.configure")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.brandPrimary, Color.brandSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func percentTile(
        icon: String,
        labelKey: LocalizedStringKey,
        pct: Int,
        amount: Decimal,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color).font(.caption)
                Text(labelKey).font(.caption.weight(.bold)).foregroundStyle(Color.textMuted)
                Spacer()
                Text("\(pct)%")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
            }
            AmountLabel(amount: amount, currency: currency, kind: .ingreso)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var allocationBar: some View {
        let totalPct = savingsPct + investmentPct
        let remaining = max(0, 100 - totalPct)

        VStack(alignment: .leading, spacing: 6) {
            Text("home.savings.distribution")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.textMuted)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    if savingsPct > 0 {
                        Rectangle()
                            .fill(Color.brandSuccess)
                            .frame(width: geo.size.width * Double(savingsPct) / 100)
                    }
                    if investmentPct > 0 {
                        Rectangle()
                            .fill(Color.brandPrimary)
                            .frame(width: geo.size.width * Double(investmentPct) / 100)
                    }
                    if remaining > 0 {
                        Rectangle()
                            .fill(Color.appSurfaceInset)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .frame(height: 10)

            HStack(spacing: 12) {
                legendDot(color: .brandSuccess, text: "\(savingsPct)%")
                legendDot(color: .brandPrimary, text: "\(investmentPct)%")
                legendDot(color: .textMuted, text: "\(remaining)% disponible")
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(Color.textMuted)
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
    }
}

// MARK: - StatsRow (ingresos + gastos con sparkline)

private struct StatsRow: View {
    let ingresos: Decimal
    let gastos: Decimal
    let incomeSpark: [Decimal]
    let expenseSpark: [Decimal]
    let currency: String
    var onTap: (BalanceBreakdownMode) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 12) {
            statTile(
                title: "Ingresos",
                amount: ingresos,
                kind: .ingreso,
                spark: incomeSpark,
                color: .brandSuccess,
                icon: "arrow.down.circle.fill"
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap(.ingresos) }
            statTile(
                title: "Gastos",
                amount: gastos,
                kind: .gasto,
                spark: expenseSpark,
                color: .brandDanger,
                icon: "arrow.up.circle.fill"
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap(.gastos) }
        }
    }

    private func statTile(
        title: String,
        amount: Decimal,
        kind: AmountLabel.Kind,
        spark: [Decimal],
        color: Color,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textMuted)
                Spacer()
            }
            AmountLabel(amount: amount, currency: currency, kind: kind)
                .font(.mcSerifAmount)

            // Sparkline 7 días
            if spark.contains(where: { $0 > 0 }) {
                Chart {
                    ForEach(Array(spark.enumerated()), id: \.offset) { idx, value in
                        LineMark(
                            x: .value("day", idx),
                            y: .value("amount", (value as NSDecimalNumber).doubleValue)
                        )
                        .foregroundStyle(color.gradient)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("day", idx),
                            y: .value("amount", (value as NSDecimalNumber).doubleValue)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [color.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .chartPlotStyle { plot in
                    plot.frame(height: 28)
                }
                .frame(height: 28)
            } else {
                Rectangle()
                    .fill(Color.appSurface)
                    .frame(height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - InsightCard

private struct InsightCard: View {
    let viewModel: HomeViewModel
    let currency: String
    @State private var showAssistant = false

    private var insight: String {
        // Insight prioritario: si hay over-budget categoría, alertar.
        if let over = overBudgetInsight() { return over }
        if let top = topCategoryInsight() { return top }
        if let spike = spikeInsight() { return spike }
        return "Cargá algunas transacciones para que te muestre insights personalizados."
    }

    private func overBudgetInsight() -> String? {
        guard let period = viewModel.period, period.readyToAssign < 0 else { return nil }
        let amt = Money.format(abs(period.readyToAssign), currency: currency, style: .compact)
        return "⚠️ Sobreasignaste \(amt) de tu presupuesto. Ajustá envelopes."
    }

    private func topCategoryInsight() -> String? {
        guard let top = viewModel.topCategories.first, viewModel.totalGastos > 0 else { return nil }
        let pct = Int(((top.total / viewModel.totalGastos) as NSDecimalNumber).doubleValue * 100)
        let amt = Money.format(top.total, currency: currency, style: .compact)
        if pct >= 35 {
            return "💡 \(top.category) concentra \(pct)% de tu gasto este mes (\(amt)). Considerá reducirlo."
        }
        return "💡 Tu mayor gasto es \(top.category): \(amt) (\(pct)% del total)."
    }

    private func spikeInsight() -> String? {
        guard viewModel.gastosGrew else { return nil }
        let delta = viewModel.totalGastos - viewModel.prevMonthGastos
        let amt = Money.format(delta, currency: currency, style: .compact)
        return "📈 Gastaste \(amt) más que el mes pasado. Hablemos."
    }

    var body: some View {
        Button {
            Haptics.play(.impactLight)
            showAssistant = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandPrimary, Color.brandSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insight del día").font(.caption.weight(.bold)).foregroundStyle(Color.textMuted)
                    Text(insight)
                        .font(.callout)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.brandPrimary.opacity(0.4), Color.brandSecondary.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAssistant) { AssistantChatView() }
    }
}

private extension HomeViewModel {
    var gastosGrew: Bool {
        guard prevMonthGastos > 0 else { return false }
        return totalGastos > prevMonthGastos * Decimal(11) / Decimal(10) // +10%
    }
}

// MARK: - ReadyToAssignCard

private struct ReadyToAssignCard: View {
    let period: BudgetPeriod?
    let currency: String

    var body: some View {
        if let p = period {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(p.readyToAssign >= 0 ? Color.brandSuccess.opacity(0.15) : Color.brandDanger.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: p.readyToAssign >= 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(p.readyToAssign >= 0 ? Color.brandSuccess : Color.brandDanger)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Por asignar").font(.caption.weight(.bold)).foregroundStyle(Color.textMuted)
                    AmountLabel(amount: p.readyToAssign, currency: currency, kind: .balance)
                        .font(.mcSerifAmount)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appSurface)
            )
        }
    }
}

// MARK: - UpcomingBillsStrip

private struct UpcomingBillsStrip: View {
    let bills: [Bill]
    let currency: String

    var body: some View {
        if !bills.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Próximos vencimientos", systemImage: "calendar.badge.exclamationmark")
                        .font(.mcH2)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("\(bills.count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.brandWarning.opacity(0.2))
                        .foregroundStyle(Color.brandWarning)
                        .clipShape(Capsule())
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(bills.prefix(8)) { bill in
                            billChip(bill)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appSurface)
            )
        }
    }

    private func billChip(_ bill: Bill) -> some View {
        let days = bill.daysUntilDue
        let urgent = days < 3
        let overdue = days < 0
        let color: Color = overdue ? .brandDanger : (urgent ? .brandWarning : .brandPrimary)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: overdue ? "exclamationmark.triangle.fill" : "calendar")
                    .font(.caption2)
                Text(dayLabel(days: days))
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(color)

            Text(bill.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            AmountLabel(amount: bill.amount, currency: bill.currency, kind: .gasto)
                .font(.callout.weight(.bold).monospacedDigit())
        }
        .frame(width: 130, alignment: .leading)
        .padding(12)
        .background(Color.appBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dayLabel(days: Int) -> String {
        if days < 0 { return "Vencido \(-days)d" }
        if days == 0 { return "Hoy" }
        if days == 1 { return "Mañana" }
        return "En \(days) días"
    }
}

// MARK: - GoalsRingsRow

private struct GoalsRingsRow: View {
    let goals: [Goal]

    var body: some View {
        if !goals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Tus metas", systemImage: "target")
                        .font(.mcH2)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("\(goals.count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.brandPrimary.opacity(0.2))
                        .foregroundStyle(Color.brandPrimary)
                        .clipShape(Capsule())
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(goals.prefix(8)) { goal in
                            goalRing(goal)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appSurface)
            )
        }
    }

    private func goalRing(_ goal: Goal) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, goal.progress)))
                    .stroke(
                        LinearGradient(
                            colors: goal.progress >= 1
                                ? [Color.brandSuccess, Color.brandSuccess]
                                : [Color.brandPrimary, Color.brandSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)
                    .animation(.easeOut(duration: 0.8), value: goal.progress)

                if let icon = goal.icon {
                    Text(icon).font(.title3)
                } else {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            Text(goal.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(width: 80)
            Text("\(Int(goal.progress * 100))%")
                .font(.caption2)
                .foregroundStyle(goal.progress >= 1 ? Color.brandSuccess : Color.brandPrimary)
        }
    }
}

// MARK: - CategoryDonutCard

private struct CategoryDonutCard: View {
    let items: [(category: String, total: Decimal)]
    let currency: String

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top categorías").font(.mcH2).foregroundStyle(Color.textPrimary)

                HStack(alignment: .top, spacing: 16) {
                    donutChart
                        .frame(width: 110, height: 110)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorFor(idx: idx))
                                    .frame(width: 8, height: 8)
                                Text(CategoryCatalog.emoji(for: item.category))
                                    .font(.caption)
                                Text(item.category)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(Money.format(item.total, currency: currency, style: .compact))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.brandDanger)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appSurface)
            )
        }
    }

    private var donutChart: some View {
        Chart {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                SectorMark(
                    angle: .value("Monto", (item.total as NSDecimalNumber).doubleValue),
                    innerRadius: .ratio(0.65),
                    angularInset: 2
                )
                .cornerRadius(3)
                .foregroundStyle(colorFor(idx: idx))
            }
        }
    }

    private func colorFor(idx: Int) -> Color {
        let palette: [Color] = [.brandPrimary, .brandSecondary, .brandWarning, .brandSuccess, .brandDanger]
        return palette[idx % palette.count]
    }
}

// MARK: - QuickShortcutsCarousel

private struct QuickShortcutsCarousel: View {
    let templates: [TransactionTemplate]

    var body: some View {
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Atajos rápidos", systemImage: "bolt.fill")
                    .font(.mcH2)
                    .foregroundStyle(Color.textPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(templates) { t in
                            shortcutCard(t)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appSurface)
            )
        }
    }

    private func shortcutCard(_ t: TransactionTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let e = t.emoji {
                    Text(e).font(.title3)
                } else {
                    Image(systemName: t.type == .gasto ? "minus" : "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(t.type == .gasto ? Color.brandDanger : Color.brandSuccess)
                }
                Text(t.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Text(Money.format(t.amount, currency: t.currency, style: .compact))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(t.type == .gasto ? Color.brandDanger.opacity(0.12) : Color.brandSuccess.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(t.type == .gasto ? Color.brandDanger.opacity(0.2) : Color.brandSuccess.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - DebtsAndPlansTiles

private struct DebtsAndPlansTiles: View {
    let debtsCount: Int
    let plansCount: Int
    let monthlyDebtCommitment: Decimal
    let currency: String

    var body: some View {
        if debtsCount > 0 || plansCount > 0 {
            HStack(spacing: 12) {
                if debtsCount > 0 {
                    tile(
                        icon: "arrow.down.to.line",
                        label: "Deudas",
                        count: debtsCount,
                        detail: monthlyDebtCommitment > 0
                            ? "\(Money.format(monthlyDebtCommitment, currency: currency, style: .compact))/mes"
                            : nil,
                        color: .brandDanger
                    )
                }
                if plansCount > 0 {
                    tile(
                        icon: "creditcard.and.123",
                        label: "Planes cuotas",
                        count: plansCount,
                        detail: nil,
                        color: .brandPrimary
                    )
                }
            }
        }
    }

    private func tile(icon: String, label: String, count: Int, detail: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
            }
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textMuted)
            if let d = detail {
                Text(d)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
        )
    }
}

// MARK: - HealthScoreCard

/// Puntaje de salud financiera compact + chip de racha. Mismo algoritmo que
/// ReportsView, con link a Reports para el breakdown detallado.
private struct HealthScoreCard: View {
    let score: Int
    let streak: Int
    @State private var showReports = false

    private var labelKey: LocalizedStringKey {
        if score >= 75 { return "reports.health.excellent" }
        if score >= 55 { return "reports.health.good" }
        if score >= 35 { return "reports.health.fair" }
        return "reports.health.poor"
    }

    private var color: Color {
        if score >= 75 { return .brandSuccess }
        if score >= 55 { return .brandPrimary }
        if score >= 35 { return .brandWarning }
        return .brandDanger
    }

    var body: some View {
        Button {
            Haptics.play(.selection)
            showReports = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)
                        .animation(.easeOut(duration: 0.8), value: score)
                    Text("\(score)")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("reports.health.title")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.textMuted)
                    Text(labelKey)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(color)
                    if streak > 0 {
                        HStack(spacing: 4) {
                            Text("🔥")
                            Text("home.streak \(streak)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.brandWarning)
                        }
                    } else {
                        Text("reports.health.tapForDetails")
                            .font(.caption2)
                            .foregroundStyle(Color.textMuted)
                    }
                }
                Spacer()
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.title3)
                    .foregroundStyle(color)
            }
            .padding(14)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showReports) {
            NavigationStack { ReportsView() }
        }
    }
}

// MARK: - MonthPDFSharePreview

/// Preview + share sheet para el PDF mensual. Se abre como hoja tras terminar
/// la generación en `HomeView.buildAndShareMonthPDF()`. Muestra una mini card
/// con el nombre del archivo + tamaño + ShareLink nativo prominente.
struct MonthPDFSharePreview: View {
    let url: URL
    let householdName: String
    @Environment(\.dismiss) private var dismiss

    private var fileSize: String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attrs?[.size] as? Int else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.brandPrimary)
                        .padding(.top, 32)

                    Text("home.sharePDF.ready")
                        .font(.mcH2)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    // Card con metadata del PDF
                    VStack(spacing: 8) {
                        HStack {
                            Label {
                                Text(url.lastPathComponent)
                                    .font(.mcCaption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            } icon: {
                                Image(systemName: "doc")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            Spacer()
                            Text(fileSize)
                                .font(.mcCaption)
                                .foregroundStyle(Color.textMuted)
                        }
                    }
                    .mcCard()

                    ShareLink(
                        item: url,
                        subject: Text("home.shareSubject \(householdName)"),
                        message: Text("home.sharePDF.message")
                    ) {
                        Label("home.sharePDF.action", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MCPrimaryButton())

                    Text("home.sharePDF.hint")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textMuted)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(Text("home.sharePDF.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - NetWorthCard

/// Widget de patrimonio neto del hogar. Muestra:
/// - Total neto en serif hero (verde si positivo, coral warm si negativo).
/// - Barra proporcional con assets / liabilities.
/// - Dos rows: Activos y Pasivos con sus montos.
/// - Ratio deuda/activos como indicador de solvencia (<30% sano, >60% alerta).
struct NetWorthCard: View {
    let breakdown: NetWorthBreakdown
    let currency: String
    let isHidden: Bool

    private var netWorthColor: Color {
        if breakdown.netWorth >= 0 { return Color.textPrimary }
        return Color.brandDanger
    }

    private var solvencyLabel: (text: LocalizedStringKey, color: Color) {
        let ratio = breakdown.debtToAssetRatio
        if ratio < 0.3 {
            return ("networth.solvency.healthy", Color.brandSuccess)
        } else if ratio < 0.6 {
            return ("networth.solvency.moderate", Color.brandWarning)
        } else {
            return ("networth.solvency.alert", Color.brandDanger)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "scale.3d")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text("networth.title")
                        .font(.mcLabel)
                        .foregroundStyle(Color.textMuted)
                    Text("networth.subtitle")
                        .font(.caption2)
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
                Text(solvencyLabel.text)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(solvencyLabel.color.opacity(0.2))
                    .foregroundStyle(solvencyLabel.color)
                    .cornerRadius(10)
            }

            // Net worth amount
            if isHidden {
                Text("•••••")
                    .font(.mcSerifDisplay)
                    .foregroundStyle(Color.textPrimary)
            } else {
                Text(Money.format(breakdown.netWorth, currency: currency, style: .auto))
                    .font(.mcSerifDisplay)
                    .foregroundStyle(netWorthColor)
                    .contentTransition(.numericText())
            }

            // Proportional bar: assets vs liabilities
            proportionBar

            // Details rows
            VStack(spacing: 8) {
                detailRow(
                    label: "networth.assets",
                    amount: breakdown.assets,
                    color: Color.brandSuccess,
                    icon: "arrow.up.circle.fill"
                )
                detailRow(
                    label: "networth.liabilities",
                    amount: breakdown.liabilities,
                    color: Color.brandDanger,
                    icon: "arrow.down.circle.fill"
                )
            }

            if breakdown.perAccount.isEmpty {
                // Sin cuentas — nudge educativo.
                Text("networth.empty.hint")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.leading)
            }
        }
        .mcCard()
    }

    private var proportionBar: some View {
        let total = breakdown.assets + breakdown.liabilities
        let assetsPct: Double = {
            let t = (total as NSDecimalNumber).doubleValue
            guard t > 0 else { return 0 }
            return (breakdown.assets as NSDecimalNumber).doubleValue / t
        }()
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.brandDanger.opacity(0.35))
                    .frame(height: 8)
                // Assets (verde) segment
                Capsule()
                    .fill(Color.brandSuccess)
                    .frame(width: geo.size.width * assetsPct, height: 8)
                    .animation(.easeOut(duration: 0.5), value: assetsPct)
            }
        }
        .frame(height: 8)
    }

    private func detailRow(
        label: LocalizedStringKey,
        amount: Decimal,
        color: Color,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body)
            Text(label)
                .font(.mcBody)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if isHidden {
                Text("•••").font(.mcSerifInline).foregroundStyle(Color.textMuted)
            } else {
                Text(Money.format(amount, currency: currency, style: .auto))
                    .font(.mcSerifInline)
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
            }
        }
    }
}

// MARK: - Balance breakdown (tap en Saldo / Ingresos / Gastos)

/// Modo del desglose. Define qué transacciones se muestran y el copy.
enum BalanceBreakdownMode: String, Identifiable {
    case balance, ingresos, gastos
    var id: String { rawValue }

    var title: String {
        switch self {
        case .balance:  "Saldo del mes"
        case .ingresos: "Ingresos del mes"
        case .gastos:   "Gastos del mes"
        }
    }
}

/// Sheet que muestra CÓMO está compuesto el importe que el user tocó en el
/// Home (Saldo / Ingresos / Gastos). Igual que Mercado Pago / Revolut: tap
/// en un total → desglose por categoría con barras + lista de movimientos.
struct BalanceBreakdownView: View {
    let mode: BalanceBreakdownMode
    let transactions: [Transaction]
    let ingresos: Decimal
    let gastos: Decimal
    let currency: String
    @Environment(\.dismiss) private var dismiss

    private var balance: Decimal { ingresos - gastos }

    private var relevantTxs: [Transaction] {
        switch mode {
        case .ingresos: transactions.filter { $0.type == .ingreso }
        case .gastos:   transactions.filter { $0.type == .gasto }
        case .balance:  transactions
        }
    }

    private var headlineAmount: Decimal {
        switch mode {
        case .ingresos: ingresos
        case .gastos:   gastos
        case .balance:  balance
        }
    }

    private var byCategory: [(category: String, total: Decimal, pct: Double)] {
        let txs: [Transaction]
        let denom: Decimal
        switch mode {
        case .ingresos: txs = transactions.filter { $0.type == .ingreso }; denom = ingresos
        case .gastos:   txs = transactions.filter { $0.type == .gasto };   denom = gastos
        case .balance:  txs = transactions.filter { $0.type == .gasto };   denom = gastos
        }
        var sums: [String: Decimal] = [:]
        for t in txs { sums[t.category, default: 0] += t.amount }
        let d = (denom as NSDecimalNumber).doubleValue
        return sums.map { (cat, total) -> (category: String, total: Decimal, pct: Double) in
            let p = d > 0 ? (total as NSDecimalNumber).doubleValue / d : 0
            return (cat, total, p)
        }
        .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headline
                        if mode == .balance { balanceSummary }
                        if !byCategory.isEmpty { categorySection }
                        movementsSection
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .gastos ? "Total gastado" : (mode == .ingresos ? "Total ingresado" : "Saldo neto"))
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            Text(Money.format(headlineAmount, currency: currency, style: .auto))
                .font(.mcSerifHero)
                .foregroundStyle(mode == .gastos ? Color.brandDanger : (mode == .ingresos ? Color.brandSuccess : Color.textPrimary))
            Text("\(relevantTxs.count) movimiento\(relevantTxs.count == 1 ? "" : "s")")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var balanceSummary: some View {
        HStack(spacing: 12) {
            summaryTile("Ingresos", ingresos, .brandSuccess, "arrow.down.circle.fill")
            summaryTile("Gastos", gastos, .brandDanger, "arrow.up.circle.fill")
        }
    }

    private func summaryTile(_ t: String, _ amt: Decimal, _ c: Color, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(c).font(.caption)
                Text(t).font(.mcCaption).foregroundStyle(Color.textMuted)
            }
            Text(Money.format(amt, currency: currency, style: .compact))
                .font(.mcSerifAmount)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .ingresos ? "Por origen" : "Por categoría")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            ForEach(byCategory.prefix(12), id: \.category) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.category)
                            .font(.mcBody)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(Money.format(row.total, currency: currency, style: .compact))
                            .font(.mcBody.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.textPrimary)
                        Text("\(Int(row.pct * 100))%")
                            .font(.mcCaption.monospacedDigit())
                            .foregroundStyle(Color.textDim)
                            .frame(width: 42, alignment: .trailing)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.appSurfaceInset).frame(height: 6)
                            Capsule()
                                .fill(mode == .ingresos ? Color.brandSuccess : Color.brandPrimary)
                                .frame(width: max(4, geo.size.width * row.pct), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var movementsSection: some View {
        let sorted = relevantTxs.sorted { $0.date > $1.date }
        let shown = Array(sorted.prefix(50))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Movimientos")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            if shown.isEmpty {
                Text("Sin movimientos este mes.")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textDim)
                    .padding(.vertical, 8)
            } else {
                ForEach(shown) { tx in
                    movementRow(tx)
                    if tx.id != shown.last?.id {
                        Divider().background(Color.appBorder)
                    }
                }
                if relevantTxs.count > 50 {
                    Text("… y \(relevantTxs.count - 50) más. Vé al tab Movimientos para verlos todos.")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textDim)
                        .padding(.top, 6)
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func movementRow(_ tx: Transaction) -> some View {
        let isGasto = tx.type == .gasto
        let df = DateFormatter()
        df.dateFormat = "dd MMM"
        df.locale = AppLocaleStorage.effectiveLocale
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isGasto ? Color.brandDanger : Color.brandSuccess).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: isGasto ? "arrow.up.right" : "arrow.down.left")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isGasto ? Color.brandDanger : Color.brandSuccess)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.note?.isEmpty == false ? tx.note! : tx.category)
                    .font(.mcBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("\(tx.category) · \(df.string(from: tx.date))")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }
            Spacer()
            Text((isGasto ? "−" : "+") + Money.format(tx.amount, currency: currency, style: .compact))
                .font(.mcBody.weight(.semibold).monospacedDigit())
                .foregroundStyle(isGasto ? Color.textPrimary : Color.brandSuccess)
        }
        .padding(.vertical, 8)
    }
}


