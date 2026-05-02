import SwiftUI
import Observation

/// Hub unificado del tab Presupuesto — paridad UX con la web.
///
/// En vez de separar cascada (WaterfallBudgetView) y editor (BudgetView),
/// esta vista mezcla ambos en una experiencia cohesiva:
/// 1. Header: month picker + ingresos + ready-to-assign
/// 2. Summary: total asignado / gastado / disponible
/// 3. Editor de envelopes inline — cada categoría con progreso + tap para editar
/// 4. Botón "+" prominente para agregar categoría
/// 5. Link a cascada detallada (WaterfallBudget) como opcional
/// 6. Link a configurar % ahorro/inversión
///
/// Reemplaza al antiguo tab "Presupuesto" que mostraba solo WaterfallBudgetView.
@MainActor
@Observable
final class BudgetHubViewModel {
    var period: BudgetPeriod?
    var allocations: [BudgetAllocation] = []
    var envelopes: [EnvelopeWithAllocation] = []
    var ingresosMes: Decimal = 0
    var gastosMes: Decimal = 0
    var selectedMonth: Date = Date()

    var isLoading = false
    var errorMessage: String?

    struct EnvelopeWithAllocation: Identifiable {
        let allocation: BudgetAllocation
        let status: EnvelopeStatus
        var id: UUID { allocation.id }
    }

    /// Total asignado en todos los envelopes del período.
    var totalAssigned: Decimal {
        allocations.reduce(Decimal(0)) { $0 + $1.allocated + $1.rolloverFromPrev }
    }

    /// Total gastado (suma de spent de cada envelope).
    var totalSpent: Decimal {
        envelopes.reduce(Decimal(0)) { $0 + $1.status.spent }
    }

    /// Disponible para asignar: ingresos del mes - total asignado.
    var readyToAssign: Decimal {
        ingresosMes - totalAssigned
    }

    func load(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let p = try await BudgetService.shared.ensurePeriodForMonth(
                householdId: householdId,
                containing: selectedMonth
            )
            self.period = p

            let allocs = try await BudgetService.shared.fetchAllocations(periodId: p.id)
            self.allocations = allocs

            // Totales de ingresos/gastos del mes
            let totals = (try? await TransactionService.shared.totals(
                householdId: householdId,
                from: p.periodStart,
                to: p.periodEnd
            )) ?? (ingresos: 0, gastos: 0)
            self.ingresosMes = totals.ingresos
            self.gastosMes = totals.gastos

            // Calcular envelope status
            var computed: [EnvelopeWithAllocation] = []
            for a in allocs {
                let budgeted = a.allocated + a.rolloverFromPrev
                let remaining = (try? await BudgetService.shared.envelopeBalance(
                    periodId: p.id, category: a.category, subcategory: a.subcategory
                )) ?? budgeted
                let spent = budgeted - remaining
                computed.append(EnvelopeWithAllocation(
                    allocation: a,
                    status: EnvelopeStatus(
                        category: a.category,
                        subcategory: a.subcategory,
                        allocated: budgeted,
                        spent: spent
                    )
                ))
            }
            self.envelopes = computed.sorted { $0.status.percentUsed > $1.status.percentUsed }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upsert(periodId: UUID, category: String, subcategory: String, allocated: Decimal, rolloverMode: RolloverMode, currency: String, householdId: UUID) async {
        do {
            let saved = try await BudgetService.shared.upsertAllocation(
                periodId: periodId,
                category: category,
                subcategory: subcategory,
                allocated: allocated,
                currency: currency
            )
            // Si cambió rollover mode, setearlo
            if saved.rolloverMode != rolloverMode {
                try await BudgetService.shared.updateRolloverMode(allocationId: saved.id, mode: rolloverMode)
            }
            await load(householdId: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(allocationId: UUID, householdId: UUID) async {
        do {
            try await BudgetService.shared.deleteAllocation(id: allocationId)
            await load(householdId: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeMonth(delta: Int) {
        let cal = Calendar.current
        selectedMonth = cal.date(byAdding: .month, value: delta, to: selectedMonth) ?? selectedMonth
    }
}

struct BudgetHubView: View {
    @Environment(AppState.self) private var appState
    @Environment(PrivacyManager.self) private var privacy
    @State private var viewModel = BudgetHubViewModel()
    @State private var editorState: EditorState?
    @State private var showWaterfall = false
    @State private var showStrategy = false

    struct EditorState: Identifiable {
        let id = UUID()
        var existing: BudgetAllocation?  // nil = nuevo
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        summaryTiles
                        envelopesSection
                        actionsSection
                        if let msg = viewModel.errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .refreshable { await reload() }
            }
            .navigationTitle(Text("tab.budget"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.play(.selection)
                        showStrategy = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .task { await reload() }
            .sheet(item: $editorState) { state in
                EnvelopeEditorSheet(
                    existing: state.existing,
                    currency: householdCurrency,
                    usedCategories: Set(viewModel.allocations.map { $0.category }),
                    onSave: { cat, sub, amount, rollover in
                        guard let p = viewModel.period, let hid = appState.currentHouseholdId else { return }
                        Task {
                            await viewModel.upsert(
                                periodId: p.id,
                                category: cat,
                                subcategory: sub,
                                allocated: amount,
                                rolloverMode: rollover,
                                currency: householdCurrency,
                                householdId: hid
                            )
                            Haptics.play(.success)
                            editorState = nil
                        }
                    },
                    onDelete: { allocation in
                        guard let hid = appState.currentHouseholdId else { return }
                        Task {
                            await viewModel.delete(allocationId: allocation.id, householdId: hid)
                            Haptics.play(.warning)
                            editorState = nil
                        }
                    }
                )
            }
            .sheet(isPresented: $showWaterfall) {
                WaterfallBudgetView()
            }
            .sheet(isPresented: $showStrategy) {
                PlanEditorView(
                    strategy: currentStrategy,
                    onSave: { newStrategy in
                        Task { await saveStrategy(newStrategy) }
                    }
                )
            }
        }
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private var currentStrategy: HouseholdStrategy {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.strategy ?? .default
    }

    // MARK: - Sections

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    Haptics.play(.selection)
                    viewModel.changeMonth(delta: -1)
                    Task { await reload() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.appSurfaceInset)
                        .clipShape(Circle())
                }.buttonStyle(.plain)
                Spacer()
                VStack(spacing: 2) {
                    Text(monthTitle).font(.title3.weight(.bold))
                        .contentTransition(.interpolate)
                    Text("budget.period").font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                }
                Spacer()
                Button {
                    Haptics.play(.selection)
                    viewModel.changeMonth(delta: 1)
                    Task { await reload() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.appSurfaceInset)
                        .clipShape(Circle())
                }.buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("budget.ready_to_assign").font(.mcLabel).foregroundStyle(Color.textMuted)
                AmountLabel(amount: viewModel.readyToAssign, currency: householdCurrency, kind: .balance)
                    .font(.mcSerifDisplay)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandPrimary.opacity(0.22),
                            Color.brandSecondary.opacity(0.12),
                            Color.appSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var summaryTiles: some View {
        HStack(spacing: 10) {
            summaryTile(
                icon: "arrow.down.circle.fill",
                labelKey: "budget.income",
                amount: viewModel.ingresosMes,
                kind: .ingreso,
                color: .brandSuccess
            )
            summaryTile(
                icon: "dot.arrowtriangles.up.right.down.left.circle",
                labelKey: "budget.assigned",
                amount: viewModel.totalAssigned,
                kind: .neutro,
                color: .brandPrimary
            )
            summaryTile(
                icon: "arrow.up.circle.fill",
                labelKey: "budget.spent",
                amount: viewModel.totalSpent,
                kind: .gasto,
                color: .brandDanger
            )
        }
    }

    private func summaryTile(icon: String, labelKey: LocalizedStringKey, amount: Decimal, kind: AmountLabel.Kind, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(labelKey).font(.caption2.weight(.bold)).foregroundStyle(Color.textMuted)
            }
            AmountLabel(amount: amount, currency: householdCurrency, kind: kind)
                .font(.mcSerifInline)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var envelopesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text("budget.categories").font(.mcH2)
                } icon: {
                    Image(systemName: "tray.2.fill").foregroundStyle(Color.brandPrimary)
                }
                .foregroundStyle(Color.textPrimary)
                Spacer()
                Button {
                    Haptics.play(.impactMedium)
                    editorState = EditorState(existing: nil)
                } label: {
                    Label {
                        Text("budget.addCategory")
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if viewModel.envelopes.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.envelopes) { env in
                    envelopeRow(env)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(Color.textMuted)
            Text("budget.empty.title")
                .font(.mcBody.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            Text("budget.empty.hint")
                .font(.caption)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
            Button {
                Haptics.play(.impactMedium)
                editorState = EditorState(existing: nil)
            } label: {
                Label("budget.addCategory", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(MCPrimaryButton())
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func envelopeRow(_ env: BudgetHubViewModel.EnvelopeWithAllocation) -> some View {
        Button {
            Haptics.play(.selection)
            editorState = EditorState(existing: env.allocation)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(CategoryCatalog.emoji(for: env.status.category))
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(env.status.category)
                            .font(.mcBody.weight(.bold))
                            .foregroundStyle(Color.textPrimary)
                        if !env.status.subcategory.isEmpty {
                            Text(env.status.subcategory)
                                .font(.caption2)
                                .foregroundStyle(Color.textMuted)
                        }
                        Text("\(Int(env.status.percentUsed * 100))% usado")
                            .font(.caption2)
                            .foregroundStyle(env.status.percentUsed > 1 ? Color.brandDanger : Color.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("budget.remaining").font(.caption2).foregroundStyle(Color.textMuted)
                        AmountLabel(amount: env.status.remaining, currency: householdCurrency, kind: .balance)
                            .font(.mcSerifInline)
                    }
                }
                ProgressView(value: min(1, env.status.percentUsed))
                    .tint(env.status.percentUsed > 0.95 ? .brandDanger : env.status.percentUsed > 0.8 ? .brandWarning : .brandSuccess)
                HStack {
                    AmountLabel(amount: env.status.spent, currency: householdCurrency, kind: .neutro)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.textMuted)
                    Text("/").font(.caption).foregroundStyle(Color.textDim)
                    AmountLabel(amount: env.status.allocated, currency: householdCurrency, kind: .neutro)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.textMuted)
                    Spacer()
                    if env.allocation.rolloverMode != .none {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                            Text(rolloverLabel(env.allocation.rolloverMode))
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.brandPrimary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.brandPrimary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(14)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.play(.selection)
                showWaterfall = true
            } label: {
                HStack {
                    Image(systemName: "chart.pie.fill")
                    Text("budget.viewCascade")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Haptics.play(.selection)
                showStrategy = true
            } label: {
                HStack {
                    Image(systemName: "banknote.fill")
                    Text("budget.configStrategy")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = AppLocaleStorage.effectiveLocale
        f.dateFormat = "LLLL yyyy"
        return f.string(from: viewModel.selectedMonth).capitalized
    }

    private func rolloverLabel(_ mode: RolloverMode) -> String {
        switch mode {
        case .none: return ""
        case .surplus: return String(localized: "budget.rollover.surplus")
        case .full: return String(localized: "budget.rollover.full")
        }
    }

    @MainActor
    private func reload() async {
        if let hid = appState.currentHouseholdId {
            await viewModel.load(householdId: hid)
        }
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
}

// MARK: - Editor Sheet

struct EnvelopeEditorSheet: View {
    let existing: BudgetAllocation?
    let currency: String
    let usedCategories: Set<String>
    let onSave: (String, String, Decimal, RolloverMode) -> Void
    let onDelete: ((BudgetAllocation) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var category: String
    @State private var subcategory: String
    @State private var amountStr: String
    @State private var rolloverMode: RolloverMode

    init(existing: BudgetAllocation?, currency: String, usedCategories: Set<String>, onSave: @escaping (String, String, Decimal, RolloverMode) -> Void, onDelete: ((BudgetAllocation) -> Void)?) {
        self.existing = existing
        self.currency = currency
        self.usedCategories = usedCategories
        self.onSave = onSave
        self.onDelete = onDelete
        _category = State(initialValue: existing?.category ?? "")
        _subcategory = State(initialValue: existing?.subcategory ?? "")
        _amountStr = State(initialValue: existing.map { "\($0.allocated)" } ?? "")
        _rolloverMode = State(initialValue: existing?.rolloverMode ?? .surplus)
    }

    private var parsedAmount: Decimal? {
        guard let d = CurrencyFormatter.parse(amountStr), d > 0 else { return nil }
        return d
    }

    /// Categorías disponibles en defaults que aún no tienen envelope (para nuevo).
    private var availableCategories: [String] {
        CategoryCatalog.defaultGastos.filter { cat in
            existing?.category == cat || !usedCategories.contains(cat)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("budget.editor.category") {
                    if existing == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableCategories, id: \.self) { cat in
                                    Button {
                                        category = cat
                                        Haptics.play(.selection)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(CategoryCatalog.emoji(for: cat))
                                            Text(cat).font(.caption.weight(.bold))
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(category == cat ? Color.brandPrimary : Color.appSurface)
                                        .foregroundStyle(category == cat ? Color.white : Color.textPrimary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        HStack {
                            Text(CategoryCatalog.emoji(for: category)).font(.title3)
                            Text(category).font(.body.weight(.bold))
                        }
                    }
                    TextField("budget.editor.subcategoryOptional", text: $subcategory)
                        .font(.caption)
                }

                Section {
                    HStack {
                        Text(currency)
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(Color.textMuted)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.appSurfaceInset)
                            .clipShape(Capsule())
                        TextField("0", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Color.brandPrimary)
                    }
                    if let amt = parsedAmount {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.brandSuccess)
                            Text("form.amount.preview \(Money.format(amt, currency: currency, style: .auto))")
                                .font(.caption.weight(.semibold))
                                .contentTransition(.numericText())
                        }
                    }
                } header: {
                    Text("budget.editor.assigned")
                } footer: {
                    Text("budget.editor.assignedHint")
                }

                Section {
                    Picker("budget.editor.rollover", selection: $rolloverMode) {
                        ForEach(RolloverMode.allCases, id: \.self) { mode in
                            Text(rolloverKey(mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(rolloverHint(rolloverMode))
                        .font(.caption2)
                        .foregroundStyle(Color.textMuted)
                } header: {
                    Text("budget.editor.rollover")
                }

                if let existing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete(existing)
                        } label: {
                            Label("budget.editor.delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(Text(existing == nil ? "budget.editor.new" : "budget.editor.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        guard let amount = parsedAmount, !category.isEmpty else { return }
                        onSave(category, subcategory, amount, rolloverMode)
                    }
                    .fontWeight(.semibold)
                    .disabled(category.isEmpty || parsedAmount == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func rolloverKey(_ mode: RolloverMode) -> LocalizedStringKey {
        switch mode {
        case .none:    return "budget.rollover.none"
        case .surplus: return "budget.rollover.surplus"
        case .full:    return "budget.rollover.full"
        }
    }

    private func rolloverHint(_ mode: RolloverMode) -> LocalizedStringKey {
        switch mode {
        case .none:    return "budget.rollover.none.hint"
        case .surplus: return "budget.rollover.surplus.hint"
        case .full:    return "budget.rollover.full.hint"
        }
    }
}
