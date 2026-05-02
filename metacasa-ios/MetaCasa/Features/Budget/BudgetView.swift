import SwiftUI
import Observation

@MainActor
@Observable
final class BudgetViewModel {
    var period: BudgetPeriod?
    var allocations: [BudgetAllocation] = []
    var envelopes: [EnvelopeStatus] = []
    var isLoading = false
    var errorMessage: String?

    func load(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let p = try await BudgetService.shared.ensurePeriodForCurrentMonth(householdId: householdId)
            self.period = p
            let allocs = try await BudgetService.shared.fetchAllocations(periodId: p.id)
            self.allocations = allocs

            var computed: [EnvelopeStatus] = []
            for a in allocs {
                let budgeted = a.allocated + a.rolloverFromPrev
                let remaining = (try? await BudgetService.shared.envelopeBalance(
                    periodId: p.id, category: a.category, subcategory: a.subcategory
                )) ?? budgeted
                let spent = budgeted - remaining
                computed.append(EnvelopeStatus(
                    category: a.category,
                    subcategory: a.subcategory,
                    allocated: budgeted,
                    spent: spent
                ))
            }
            self.envelopes = computed.sorted { $0.percentUsed > $1.percentUsed }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upsertAllocation(category: String, allocated: Decimal, currency: String) async {
        guard let p = period else { return }
        do {
            _ = try await BudgetService.shared.upsertAllocation(
                periodId: p.id,
                category: category,
                subcategory: "",
                allocated: allocated,
                currency: currency
            )
            await load(householdId: p.householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BudgetView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = BudgetViewModel()
    @State private var showEditor = false
    @State private var editingCategory = ""
    @State private var editingAmount = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        readyToAssignCard
                        envelopesSection
                        addEnvelopeButton
                        if let msg = viewModel.errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .refreshable { await load() }
            }
            .navigationTitle(Text("tab.budget"))
            .task { await load() }
            .sheet(isPresented: $showEditor) { allocEditor }
        }
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private func load() async {
        if let hid = appState.currentHouseholdId {
            await viewModel.load(householdId: hid)
        }
    }

    private var readyToAssignCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("budget.available").font(.mcLabel).foregroundStyle(Color.textMuted)
            // `.balance`: si sobreasignaste envelopes y el remanente queda
            // negativo, muestra "-$X" rojo (señal de alerta); si queda
            // positivo (plata por asignar), verde.
            AmountLabel(
                amount: viewModel.period?.readyToAssign ?? 0,
                currency: householdCurrency,
                kind: .balance
            ).font(.mcDisplay)
            if let p = viewModel.period {
                Text(periodLabel(p))
                    .font(.mcCaption).foregroundStyle(Color.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    private var envelopesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("budget.categories").font(.mcH2).foregroundStyle(Color.textPrimary)
            if viewModel.envelopes.isEmpty {
                Text("budget.empty")
                    .font(.mcBody)
                    .foregroundStyle(Color.textMuted)
                    .padding(.vertical, 12)
            } else {
                ForEach(viewModel.envelopes, id: \.category) { env in
                    envelopeRow(env)
                }
            }
        }
    }

    private func envelopeRow(_ env: EnvelopeStatus) -> some View {
        Button {
            editingCategory = env.category
            editingAmount = ""
            showEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(CategoryCatalog.emoji(for: env.category))
                    Text(env.category).font(.mcBody.weight(.bold)).foregroundStyle(Color.textPrimary)
                    Spacer()
                    // `.balance`: remaining puede ser positivo (te sobra) o
                    // negativo (over-budget). El kind decide signo + color
                    // automáticamente — no necesitamos la rama isOverBudget.
                    AmountLabel(
                        amount: env.remaining,
                        currency: householdCurrency,
                        kind: .balance
                    ).font(.mcBody.weight(.bold))
                }
                ProgressView(value: env.percentUsed)
                    .tint(env.percentUsed > 0.95 ? .brandDanger : env.percentUsed > 0.8 ? .brandWarning : .brandSuccess)
                HStack {
                    MoneyText(amount: env.spent, currency: householdCurrency)
                        .font(.mcCaption).foregroundStyle(Color.textMuted)
                    Text("/").font(.mcCaption).foregroundStyle(Color.textDim)
                    MoneyText(amount: env.allocated, currency: householdCurrency)
                        .font(.mcCaption).foregroundStyle(Color.textMuted)
                }
            }
            .mcCard()
        }
        .buttonStyle(.plain)
    }

    private var addEnvelopeButton: some View {
        Button {
            editingCategory = ""
            editingAmount = ""
            showEditor = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("budget.assign")
            }
        }
        .buttonStyle(MCSecondaryButton())
    }

    private var allocEditor: some View {
        NavigationStack {
            Form {
                Section("Categoría") {
                    if editingCategory.isEmpty {
                        Picker("Elegir categoría", selection: $editingCategory) {
                            Text("Seleccionar...").tag("")
                            ForEach(CategoryCatalog.defaultGastos, id: \.self) { Text($0).tag($0) }
                        }
                    } else {
                        Text(editingCategory).foregroundStyle(.primary)
                    }
                }
                Section("Monto asignado (\(householdCurrency))") {
                    TextField("0", text: $editingAmount)
                        .keyboardType(.decimalPad)
                }
                Button("Guardar") {
                    guard let amt = CurrencyFormatter.parse(editingAmount), amt > 0, !editingCategory.isEmpty else { return }
                    Task {
                        await viewModel.upsertAllocation(
                            category: editingCategory,
                            allocated: amt,
                            currency: householdCurrency
                        )
                        showEditor = false
                    }
                }
                .disabled(editingCategory.isEmpty || CurrencyFormatter.parse(editingAmount) == nil)
            }
            .navigationTitle(Text("Asignar"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showEditor = false }
                }
            }
        }
    }

    private func periodLabel(_ p: BudgetPeriod) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL yyyy"
        fmt.locale = Locale(identifier: "es")
        return fmt.string(from: p.periodStart).capitalized
    }
}
