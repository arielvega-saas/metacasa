import SwiftUI
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var totalIngresos: Decimal = 0
    var totalGastos: Decimal = 0
    var topGastos: [Transaction] = []
    var period: BudgetPeriod?
    var isLoading = false
    var errorMessage: String?

    var balance: Decimal { totalIngresos - totalGastos }

    func load(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let now = Date()
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: now)
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59), to: start)
            else { return }

            async let totals = TransactionService.shared.totals(householdId: householdId, from: start, to: end)
            async let transactions = TransactionService.shared.fetchForPeriod(householdId: householdId, from: start, to: end, limit: 50)
            async let budgetPeriod = BudgetService.shared.fetchPeriod(householdId: householdId, containing: now)

            let t = try await totals
            self.totalIngresos = t.ingresos
            self.totalGastos = t.gastos

            let txs = try await transactions
            self.topGastos = Array(txs.filter { $0.type == .gasto }.sorted { $0.amount > $1.amount }.prefix(5))

            self.period = try await budgetPeriod
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        summarySection
                        readyToAssignCard
                        topExpensesSection
                        if let msg = viewModel.errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .refreshable { await reload() }
            }
            .navigationTitle(householdName)
            .navigationBarTitleDisplayMode(.large)
            .task { await reload() }
        }
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }
    private var householdName: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.name ?? "Hogar"
    }

    private func reload() async {
        if let hid = appState.currentHouseholdId {
            await viewModel.load(householdId: hid)
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saldo del mes").font(.mcLabel).foregroundStyle(Color.textMuted)
            AmountLabel(
                amount: viewModel.balance,
                currency: householdCurrency,
                kind: viewModel.balance >= 0 ? .ingreso : .gasto
            )
            .font(.mcDisplay)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    private var summarySection: some View {
        HStack(spacing: 12) {
            summaryTile(title: "Ingresos", amount: viewModel.totalIngresos, kind: .ingreso)
            summaryTile(title: "Gastos", amount: viewModel.totalGastos, kind: .gasto)
        }
    }

    private func summaryTile(title: String, amount: Decimal, kind: AmountLabel.Kind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.mcLabel).foregroundStyle(Color.textMuted)
            AmountLabel(amount: amount, currency: householdCurrency, kind: kind)
                .font(.mcAmount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    @ViewBuilder
    private var readyToAssignCard: some View {
        if let p = viewModel.period {
            VStack(alignment: .leading, spacing: 6) {
                Text("Disponible para asignar").font(.mcLabel).foregroundStyle(Color.textMuted)
                AmountLabel(amount: p.readyToAssign, currency: householdCurrency, kind: .neutro)
                    .font(.mcAmount)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .mcCard()
        }
    }

    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top gastos del mes").font(.mcH2).foregroundStyle(Color.textPrimary)
            if viewModel.topGastos.isEmpty {
                Text("Sin gastos todavía este mes")
                    .font(.mcBody)
                    .foregroundStyle(Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .mcCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.topGastos.indices, id: \.self) { i in
                        TransactionRow(transaction: viewModel.topGastos[i], currency: householdCurrency)
                        if i < viewModel.topGastos.count - 1 {
                            Divider().background(Color.appBorder)
                        }
                    }
                }
                .mcCard()
            }
        }
    }
}
