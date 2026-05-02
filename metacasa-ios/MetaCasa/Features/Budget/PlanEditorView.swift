import SwiftUI
import Observation

/// Plan Editor visual — port del "PlanEditor" de la PWA (App.jsx:1024+).
///
/// Combina la cascada waterfall (visualización proporcional tipo Sankey) con
/// los controles de configuración (sliders de ahorro/inversión, toggles de
/// inclusión). Al mover un slider, TODA la cascada se re-calcula en vivo.
/// Al guardar, persiste la nueva `HouseholdStrategy`.
@MainActor
@Observable
final class PlanEditorViewModel {
    var localStrategy: HouseholdStrategy
    var transactions: [Transaction] = []
    var accounts: [Account] = []
    var fixedExpenses: [RecurringTransaction] = []
    var bills: [Bill] = []
    var installmentPayments: [(plan: InstallmentPlan, payment: InstallmentPayment)] = []
    var debts: [Debt] = []
    var sharedAllocations: [BudgetAllocation] = []
    var isLoading = false

    init(strategy: HouseholdStrategy) {
        self.localStrategy = strategy
    }

    /// Calcula la cascada en vivo con la strategy actual (local).
    var result: WaterfallCalculator.Result {
        WaterfallCalculator(
            transactions: transactions,
            accounts: accounts,
            fixedExpenses: fixedExpenses,
            bills: bills,
            installmentPayments: installmentPayments,
            debts: debts,
            sharedAllocations: sharedAllocations,
            strategy: localStrategy
        ).calculate()
    }

    func load(householdId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59), to: start)
        else { return }

        let yearVal = cal.component(.year, from: start)
        let monthVal = cal.component(.month, from: start)

        async let txsTask = TransactionService.shared.fetchForPeriod(householdId: householdId, from: start, to: end, limit: 2000)
        async let accountsTask = AccountService.shared.fetchAll(householdId: householdId, includingInactive: false)
        async let recurringTask = RecurringService.shared.fetchAll(householdId: householdId)
        async let billsTask = BillService.shared.fetchForMonth(householdId: householdId, year: yearVal, month: monthVal)
        async let debtsTask = DebtService.shared.fetchAll(householdId: householdId, includeSettled: false)
        async let plansTask = InstallmentService.shared.fetchPlans(householdId: householdId, includeCompleted: false)

        self.transactions = (try? await txsTask) ?? []
        self.accounts = (try? await accountsTask) ?? []
        self.fixedExpenses = (try? await recurringTask) ?? []
        self.bills = (try? await billsTask) ?? []
        self.debts = (try? await debtsTask) ?? []

        let plans = (try? await plansTask) ?? []
        var allPayments: [(plan: InstallmentPlan, payment: InstallmentPayment)] = []
        for plan in plans {
            let payments = (try? await InstallmentService.shared.fetchPayments(planId: plan.id)) ?? []
            let monthPayments = payments.filter { $0.periodYear == yearVal && $0.periodMonth == monthVal }
            for p in monthPayments {
                allPayments.append((plan, p))
            }
        }
        self.installmentPayments = allPayments
    }
}

@MainActor
struct PlanEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlanEditorViewModel
    let onSave: (HouseholdStrategy) -> Void

    init(strategy: HouseholdStrategy, onSave: @escaping (HouseholdStrategy) -> Void) {
        self._viewModel = State(initialValue: PlanEditorViewModel(strategy: strategy))
        self.onSave = onSave
    }

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private var result: WaterfallCalculator.Result { viewModel.result }

    /// Para escalar las barras de la cascada visualmente.
    private var maxBlock: Decimal {
        max(
            result.totalIncome,
            result.fixedDeduction,
            result.billsDeduction,
            result.installmentsDeduction,
            result.debtPaymentsDeduction,
            result.savingsAllocation,
            result.investmentAllocation,
            abs(result.remainder)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        if viewModel.isLoading {
                            ProgressView().padding(.top, 40)
                        } else {
                            incomeHeader
                            cascadeBlocks
                            slidersCard
                            inclusionsCard
                            remainderBadge
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
                }
            }
            .navigationTitle(Text("plan.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        onSave(viewModel.localStrategy)
                        Haptics.play(.success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                if let hid = appState.currentHouseholdId {
                    await viewModel.load(householdId: hid)
                }
            }
        }
    }

    // MARK: - Income header

    private var incomeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Color.brandSuccess)
                Text("plan.income.total")
                    .font(.mcLabel)
                    .foregroundStyle(Color.textMuted)
                Spacer()
            }
            AmountLabel(amount: result.totalIncome, currency: currency, kind: .ingreso)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.brandSuccess.opacity(0.22), Color.brandSuccess.opacity(0.08), Color.appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Cascade blocks

    private var cascadeBlocks: some View {
        VStack(spacing: 8) {
            cascadeConnector
            cascadeBlock(
                icon: "arrow.triangle.2.circlepath",
                labelKey: "plan.fixed",
                amount: result.fixedDeduction,
                color: .brandDanger,
                kind: .gasto
            )
            cascadeConnector
            cascadeBlock(
                icon: "calendar.badge.exclamationmark",
                labelKey: "plan.bills",
                amount: result.billsDeduction,
                color: .brandWarning,
                kind: .gasto,
                optional: !viewModel.localStrategy.includeBillsInWaterfall
            )
            cascadeConnector
            cascadeBlock(
                icon: "creditcard.and.123",
                labelKey: "plan.installments",
                amount: result.installmentsDeduction,
                color: .brandWarning,
                kind: .gasto,
                optional: !viewModel.localStrategy.includeInstallmentsInWaterfall
            )
            cascadeConnector
            cascadeBlock(
                icon: "arrow.down.to.line",
                labelKey: "plan.debts",
                amount: result.debtPaymentsDeduction,
                color: .brandWarning,
                kind: .gasto,
                optional: !viewModel.localStrategy.includeDebtPaymentsInWaterfall
            )
            if result.sharedBudgetsDeduction > 0 {
                cascadeConnector
                cascadeBlock(
                    icon: "person.2.fill",
                    labelKey: "plan.sharedBudget",
                    amount: result.sharedBudgetsDeduction,
                    color: .brandPrimary,
                    kind: .gasto
                )
            }
            cascadeConnector
            cascadeBlock(
                icon: "banknote.fill",
                labelKey: "plan.savings",
                amount: result.savingsAllocation,
                color: .brandSuccess,
                kind: .neutro,
                highlight: viewModel.localStrategy.savingsPct > 0
            )
            cascadeConnector
            cascadeBlock(
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                labelKey: "plan.investment",
                amount: result.investmentAllocation,
                color: .brandSecondary,
                kind: .neutro,
                highlight: viewModel.localStrategy.investmentPct > 0
            )
        }
    }

    private func cascadeBlock(
        icon: String,
        labelKey: LocalizedStringKey,
        amount: Decimal,
        color: Color,
        kind: AmountLabel.Kind,
        optional: Bool = false,
        highlight: Bool = false
    ) -> some View {
        let ratio = maxBlock > 0
            ? min(1.0, CGFloat(truncating: (amount / maxBlock) as NSNumber))
            : 0
        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.callout.weight(.bold))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(labelKey)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(optional ? Color.textMuted : Color.textPrimary)
                    if optional {
                        Text("plan.excluded")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.textMuted.opacity(0.15))
                            .foregroundStyle(Color.textMuted)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    AmountLabel(amount: amount, currency: currency, kind: kind)
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .contentTransition(.numericText())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.appSurfaceInset)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * ratio, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: amount)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(12)
        .background(
            highlight
                ? AnyShapeStyle(LinearGradient(colors: [color.opacity(0.12), Color.appSurface], startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(Color.appSurface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    optional ? Color.textDim.opacity(0.3) : color.opacity(0.2),
                    lineWidth: 1
                )
        )
        .opacity(optional ? 0.5 : 1)
    }

    private var cascadeConnector: some View {
        Image(systemName: "arrow.down")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.textDim)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Sliders

    private var slidersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Color.brandPrimary)
                Text("plan.configure").font(.mcH2).foregroundStyle(Color.textPrimary)
                Spacer()
            }

            sliderRow(
                icon: "banknote.fill",
                labelKey: "plan.savings",
                color: .brandSuccess,
                bindingPct: Binding(
                    get: { Double(truncating: viewModel.localStrategy.savingsPct as NSNumber) },
                    set: { viewModel.localStrategy.savingsPct = Decimal($0) }
                )
            )

            Divider()

            sliderRow(
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                labelKey: "plan.investment",
                color: .brandSecondary,
                bindingPct: Binding(
                    get: { Double(truncating: viewModel.localStrategy.investmentPct as NSNumber) },
                    set: { viewModel.localStrategy.investmentPct = Decimal($0) }
                )
            )
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sliderRow(icon: String, labelKey: LocalizedStringKey, color: Color, bindingPct: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(labelKey).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(bindingPct.wrappedValue))%")
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
            Slider(
                value: bindingPct,
                in: 0...90,
                step: 1,
                onEditingChanged: { editing in
                    if !editing { Haptics.play(.impactLight) }
                }
            )
            .tint(color)
        }
    }

    // MARK: - Inclusions

    private var inclusionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle").foregroundStyle(Color.brandPrimary)
                Text("plan.inclusions").font(.mcH2).foregroundStyle(Color.textPrimary)
                Spacer()
            }
            Toggle(isOn: Binding(
                get: { viewModel.localStrategy.includeBillsInWaterfall },
                set: { viewModel.localStrategy.includeBillsInWaterfall = $0 }
            )) {
                Label("plan.bills", systemImage: "calendar.badge.exclamationmark")
            }
            Toggle(isOn: Binding(
                get: { viewModel.localStrategy.includeInstallmentsInWaterfall },
                set: { viewModel.localStrategy.includeInstallmentsInWaterfall = $0 }
            )) {
                Label("plan.installments", systemImage: "creditcard.and.123")
            }
            Toggle(isOn: Binding(
                get: { viewModel.localStrategy.includeDebtPaymentsInWaterfall },
                set: { viewModel.localStrategy.includeDebtPaymentsInWaterfall = $0 }
            )) {
                Label("plan.debts", systemImage: "arrow.down.to.line")
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Remainder

    private var remainderBadge: some View {
        let isPositive = result.remainder >= 0
        let color: Color = isPositive ? .brandSuccess : .brandDanger
        return VStack(spacing: 4) {
            Text("plan.remainder")
                .font(.mcLabel.weight(.bold))
                .foregroundStyle(Color.textMuted)
            AmountLabel(amount: result.remainder, currency: currency, kind: .balance)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text(isPositive ? "plan.remainder.hint.positive" : "plan.remainder.hint.negative")
                .font(.caption)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [color.opacity(0.15), Color.appSurface],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(color.opacity(0.4), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
