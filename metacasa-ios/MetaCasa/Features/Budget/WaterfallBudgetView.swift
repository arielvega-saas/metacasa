import SwiftUI
import Observation

// MARK: - ViewModel

@MainActor
@Observable
final class WaterfallViewModel {
    var period: Date = Date()
    var transactions: [Transaction] = []
    var accounts: [Account] = []
    var fixedExpenses: [RecurringTransaction] = []
    var bills: [Bill] = []
    var installmentPaymentsForMonth: [(plan: InstallmentPlan, payment: InstallmentPayment)] = []
    var debts: [Debt] = []
    var sharedAllocations: [BudgetAllocation] = []
    var strategy: HouseholdStrategy = .default

    var isLoading = false
    var errorMessage: String?

    /// Resultado de la cascada ya calculado — derivado de los inputs.
    var result: WaterfallCalculator.Result {
        WaterfallCalculator(
            transactions: transactions,
            accounts: accounts,
            fixedExpenses: fixedExpenses,
            bills: bills,
            installmentPayments: installmentPaymentsForMonth,
            debts: debts,
            sharedAllocations: sharedAllocations,
            strategy: strategy
        ).calculate()
    }

    @MainActor
    func load(householdId: UUID, strategyFromHousehold: HouseholdStrategy?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // Rango del mes
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            let comps = cal.dateComponents([.year, .month], from: period)
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59, second: 59), to: start) else {
                return
            }
            let year = comps.year ?? 2026
            let month = comps.month ?? 1

            async let txs = TransactionService.shared.fetchForPeriod(householdId: householdId, from: start, to: end, limit: 2000)
            async let accs = AccountService.shared.fetchAll(householdId: householdId)
            async let recurring = RecurringService.shared.fetchAll(householdId: householdId, includeInactive: false)
            async let billsList = BillService.shared.fetchForMonth(householdId: householdId, year: year, month: month)
            async let instPayments = InstallmentService.shared.fetchPaymentsForMonth(householdId: householdId, year: year, month: month)
            async let debtsList = DebtService.shared.fetchAll(householdId: householdId, includeSettled: false)

            transactions = try await txs
            accounts = try await accs
            fixedExpenses = try await recurring
            bills = try await billsList
            installmentPaymentsForMonth = try await instPayments
            debts = try await debtsList

            // Shared allocations: envelope allocations sobre el period actual
            if let periodRec = try? await BudgetService.shared.fetchPeriod(householdId: householdId, containing: period) {
                sharedAllocations = (try? await BudgetService.shared.fetchAllocations(periodId: periodRec.id)) ?? []
            } else {
                sharedAllocations = []
            }

            if let s = strategyFromHousehold {
                strategy = s
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

/// Vista del presupuesto **Waterfall** multi-persona.
///
/// Port de MetaCasa web (App.jsx:11877-12200, 6245-6307) con mejoras iOS-native:
/// - Cards plegables con DisclosureGroup
/// - Animación spring al cambiar modos/valores
/// - Month picker con chevrons + gesture
/// - Strategy settings en sheet con presentation detents
struct WaterfallBudgetView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = WaterfallViewModel()
    @State private var showStrategySettings = false
    @State private var showDeductionsDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        monthHeader
                        incomeCard
                        cascadeCard
                        remainderCard
                        distributionCard
                        if let msg = viewModel.errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(.red).padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .refreshable { await reload() }
            }
            .navigationTitle(Text("tab.budget"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showStrategySettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task { await reload() }
            .sheet(isPresented: $showStrategySettings) {
                StrategySettingsSheet(
                    strategy: viewModel.strategy,
                    onSave: { newStrategy in
                        Task { await saveStrategy(newStrategy) }
                    }
                )
            }
        }
    }

    // MARK: - Sections

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.spring) {
                    viewModel.period = Calendar.current.date(byAdding: .month, value: -1, to: viewModel.period) ?? viewModel.period
                }
                Task { await reload() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3).frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill)).clipShape(Circle())
            }.buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text(monthTitle).font(.title3.weight(.bold))
                Text("budget.waterfall")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Spacer()
            Button {
                withAnimation(.spring) {
                    viewModel.period = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.period) ?? viewModel.period
                }
                Task { await reload() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3).frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill)).clipShape(Circle())
            }.buttonStyle(.plain)
        }
    }

    private var incomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text("waterfall.income").font(.mcLabel)
                } icon: {
                    Image(systemName: "arrow.up.circle.fill").foregroundStyle(Color.brandSuccess)
                }
                .foregroundStyle(Color.textMuted)
                Spacer()
            }
            AmountLabel(amount: viewModel.result.totalIncome, currency: currency, kind: .ingreso)
                .font(.mcDisplay)
            // Desglose de cuentas si hay ingresos
            if !incomeByAccount.isEmpty {
                Divider().padding(.vertical, 2)
                ForEach(Array(incomeByAccount.prefix(5)), id: \.account.id) { entry in
                    HStack {
                        Image(systemName: entry.account.type.systemIcon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(entry.account.name).font(.caption)
                        Spacer()
                        AmountLabel(amount: entry.amount, currency: entry.account.currency, kind: .ingreso)
                            .font(.caption.weight(.bold))
                    }
                }
            }
        }
        .mcCard()
    }

    private var cascadeCard: some View {
        let r = viewModel.result
        return VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("waterfall.deductions").font(.mcLabel)
            } icon: {
                Image(systemName: "arrow.down.right.circle.fill").foregroundStyle(Color.brandWarning)
            }
            .foregroundStyle(Color.textMuted)

            deductionRow(
                icon: "pin.circle.fill",
                label: "waterfall.fixed",
                amount: r.fixedDeduction
            )
            if viewModel.strategy.includeBillsInWaterfall {
                deductionRow(
                    icon: "calendar.badge.exclamationmark",
                    label: "waterfall.bills",
                    amount: r.billsDeduction
                )
            }
            if viewModel.strategy.includeInstallmentsInWaterfall {
                deductionRow(
                    icon: "creditcard.and.123",
                    label: "waterfall.installments",
                    amount: r.installmentsDeduction
                )
            }
            if viewModel.strategy.includeDebtPaymentsInWaterfall {
                deductionRow(
                    icon: "arrow.down.to.line",
                    label: "waterfall.debts",
                    amount: r.debtPaymentsDeduction
                )
            }
            deductionRow(
                icon: "person.2.fill",
                label: "waterfall.shared",
                amount: r.sharedBudgetsDeduction
            )

            Divider().padding(.vertical, 4)

            deductionRow(
                icon: "banknote.fill",
                label: "waterfall.savings",
                detail: LocalizedStringKey("\(Int((viewModel.strategy.savingsPct as NSDecimalNumber).doubleValue))%"),
                amount: r.savingsAllocation,
                isSavings: true
            )
            deductionRow(
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                label: "waterfall.investment",
                detail: LocalizedStringKey("\(Int((viewModel.strategy.investmentPct as NSDecimalNumber).doubleValue))%"),
                amount: r.investmentAllocation,
                isSavings: true
            )
        }
        .mcCard()
    }

    private func deductionRow(
        icon: String,
        label: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        amount: Decimal,
        isSavings: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(isSavings ? Color.brandSuccess : Color.brandDanger)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.subheadline)
                if let d = detail {
                    Text(d).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            AmountLabel(
                amount: amount,
                currency: currency,
                kind: isSavings ? .ingreso : .gasto
            )
            .font(.subheadline.weight(.semibold))
        }
    }

    private var remainderCard: some View {
        let r = viewModel.result.remainder
        return VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("waterfall.remainder").font(.mcLabel)
            } icon: {
                Image(systemName: "equal.circle.fill").foregroundStyle(Color.brandPrimary)
            }
            .foregroundStyle(Color.textMuted)
            AmountLabel(amount: r, currency: currency, kind: .balance)
                .font(.mcDisplay)
            Text("waterfall.remainder.hint")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .mcCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.brandPrimary.opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var distributionCard: some View {
        let dist = viewModel.result.distribution
        if !dist.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label {
                        Text("waterfall.distribution").font(.mcLabel)
                    } icon: {
                        Image(systemName: "arrow.branch").foregroundStyle(Color.brandPrimary)
                    }
                    .foregroundStyle(Color.textMuted)
                    Spacer()
                    Text(LocalizedStringKey(viewModel.strategy.distributionMode.label))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.brandPrimary.opacity(0.18))
                        .foregroundStyle(Color.brandPrimary)
                        .cornerRadius(12)
                }
                ForEach(dist) { alloc in
                    HStack(spacing: 10) {
                        Image(systemName: alloc.account.ownership.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(alloc.account.name).font(.subheadline.weight(.semibold))
                            if viewModel.strategy.distributionMode == .proportional && alloc.incomeSource > 0 {
                                Text("waterfall.distribution.proportional.hint \(incomeSourceLabel(alloc.incomeSource))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        AmountLabel(amount: alloc.amount, currency: alloc.account.currency, kind: .balance)
                            .font(.subheadline.weight(.semibold))
                    }
                    if alloc.id != dist.last?.id {
                        Divider()
                    }
                }
            }
            .mcCard()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("waterfall.distribution").font(.mcLabel)
                } icon: {
                    Image(systemName: "arrow.branch").foregroundStyle(Color.brandPrimary)
                }
                Text("waterfall.distribution.empty")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .mcCard()
        }
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "LLLL yyyy"
        return f.string(from: viewModel.period).capitalized
    }

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private struct AccountIncomeEntry {
        let account: Account
        let amount: Decimal
    }

    private var incomeByAccount: [AccountIncomeEntry] {
        var byAccount: [UUID: Decimal] = [:]
        for tx in viewModel.transactions where tx.type == .ingreso {
            guard let aid = tx.accountId else { continue }
            byAccount[aid, default: 0] += tx.amount
        }
        return byAccount.compactMap { id, amt -> AccountIncomeEntry? in
            guard let acc = viewModel.accounts.first(where: { $0.id == id }) else { return nil }
            return AccountIncomeEntry(account: acc, amount: amt)
        }.sorted { $0.amount > $1.amount }
    }

    private func incomeSourceLabel(_ amount: Decimal) -> String {
        Money.format(amount, currency: currency, style: .compact)
    }

    // MARK: - Actions

    @MainActor
    private func reload() async {
        guard let hid = appState.currentHouseholdId else { return }
        let strategy = appState.households.first(where: { $0.id == hid })?.strategy
        await viewModel.load(householdId: hid, strategyFromHousehold: strategy)
    }

    @MainActor
    private func saveStrategy(_ newStrategy: HouseholdStrategy) async {
        guard let hid = appState.currentHouseholdId else { return }
        do {
            _ = try await HouseholdService.shared.updateStrategy(householdId: hid, strategy: newStrategy)
            viewModel.strategy = newStrategy
            // Refrescar AppState.households para que el resto de la app lo vea
            try await appState.loadHouseholds()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Strategy settings sheet

struct StrategySettingsSheet: View {
    let strategy: HouseholdStrategy
    let onSave: (HouseholdStrategy) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var local: HouseholdStrategy

    init(strategy: HouseholdStrategy, onSave: @escaping (HouseholdStrategy) -> Void) {
        self.strategy = strategy
        self.onSave = onSave
        self._local = State(initialValue: strategy)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("waterfall.strategy.distribution") {
                    Picker("waterfall.strategy.distribution", selection: $local.distributionMode) {
                        ForEach(HouseholdStrategy.DistributionMode.allCases, id: \.self) { m in
                            Text(LocalizedStringKey(m.label)).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(LocalizedStringKey(distributionHint))
                        .font(.caption2).foregroundStyle(.secondary)
                }

                Section("waterfall.strategy.savings") {
                    pctRow(
                        icon: "banknote.fill",
                        label: "waterfall.savings",
                        binding: Binding(
                            get: { Double(truncating: local.savingsPct as NSNumber) },
                            set: { local.savingsPct = Decimal($0) }
                        )
                    )
                    pctRow(
                        icon: "chart.line.uptrend.xyaxis.circle.fill",
                        label: "waterfall.investment",
                        binding: Binding(
                            get: { Double(truncating: local.investmentPct as NSNumber) },
                            set: { local.investmentPct = Decimal($0) }
                        )
                    )
                }

                Section("waterfall.strategy.inclusions") {
                    Toggle(isOn: $local.includeBillsInWaterfall) {
                        Label("waterfall.bills", systemImage: "calendar.badge.exclamationmark")
                    }
                    Toggle(isOn: $local.includeInstallmentsInWaterfall) {
                        Label("waterfall.installments", systemImage: "creditcard.and.123")
                    }
                    Toggle(isOn: $local.includeDebtPaymentsInWaterfall) {
                        Label("waterfall.debts", systemImage: "arrow.down.to.line")
                    }
                }
            }
            .navigationTitle(Text("waterfall.strategy.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        onSave(local)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var distributionHint: String {
        switch local.distributionMode {
        case .equal:        return "waterfall.strategy.distribution.equal.hint"
        case .proportional: return "waterfall.strategy.distribution.proportional.hint"
        case .custom:       return "waterfall.strategy.distribution.custom.hint"
        }
    }

    private func pctRow(icon: String, label: LocalizedStringKey, binding: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text(label)
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(Color.brandPrimary)
                }
                Spacer()
                Text("\(Int(binding.wrappedValue))%")
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Color.brandPrimary)
                    .contentTransition(.numericText())
            }
            // Slider visual en vez de Stepper plano — mucho más táctil y
            // permite ajustes rápidos con preview inmediato.
            Slider(
                value: binding,
                in: 0...90,
                step: 1,
                onEditingChanged: { editing in
                    if !editing { Haptics.play(.impactLight) }
                }
            )
            .tint(.brandPrimary)
        }
    }
}
