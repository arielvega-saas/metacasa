import SwiftUI

struct DebtsListView: View {
    @Environment(AppState.self) private var appState
    @State private var debts: [Debt] = []
    @State private var showAdd = false
    @State private var editing: Debt?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if isLoading && debts.isEmpty {
                    ProgressView().tint(.white)
                } else if debts.isEmpty {
                    ContentUnavailableView(
                        String(localized: "debts.empty.title"),
                        systemImage: "arrow.down.to.line",
                        description: Text("debts.empty.hint")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            totalCard
                            ForEach(debts) { d in
                                NavigationLink {
                                    DebtDetailView(debt: d, onChange: { Task { await load() } })
                                } label: {
                                    DebtRow(debt: d)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle(Text("more.debts"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddDebtView { await load() } }
        .sheet(item: $editing) { d in AddDebtView(editing: d) { await load() } }
        .task { await load() }
        .refreshable { await load() }
    }

    private var totalCard: some View {
        let activeDebts = debts.filter { $0.status == .active }
        let totalBalance = activeDebts.reduce(Decimal(0)) { $0 + $1.currentBalance }
        let monthlyCommitment = activeDebts.compactMap { $0.monthlyPayment }.reduce(Decimal(0), +)
        return VStack(alignment: .leading, spacing: 6) {
            Text("debts.total.label").font(.mcLabel).foregroundStyle(Color.textMuted)
            AmountLabel(amount: totalBalance, currency: householdCurrency, kind: .gasto)
                .font(.mcDisplay)
            if monthlyCommitment > 0 {
                HStack {
                    Text("debts.total.monthly").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    AmountLabel(amount: monthlyCommitment, currency: householdCurrency, kind: .gasto)
                        .font(.caption.weight(.bold))
                }
            }
        }
        .mcCard()
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    @MainActor
    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        debts = (try? await DebtService.shared.fetchAll(householdId: hid)) ?? []
    }
}

private struct DebtRow: View {
    let debt: Debt
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(debt.creditor)
                        .font(.mcBody.weight(.bold))
                        .foregroundStyle(Color.textPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "percent").font(.caption2)
                        Text("\(formatted(debt.annualRate))%")
                            .font(.caption).foregroundStyle(.secondary)
                        if let months = debt.estimatedMonthsToPayoff {
                            Text("•").font(.caption).foregroundStyle(.tertiary)
                            Text("debts.row.months \(months)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                AmountLabel(amount: debt.currentBalance, currency: debt.currency, kind: .gasto)
                    .font(.mcBody.weight(.bold))
            }
            ProgressView(value: debt.progress)
                .tint(Color.brandPrimary)
            HStack {
                Text("debts.row.paid")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(debt.progress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.brandPrimary)
            }
        }
        .mcCard()
    }

    private func formatted(_ d: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2; nf.minimumFractionDigits = 0
        return nf.string(from: d as NSDecimalNumber) ?? "\(d)"
    }
}
