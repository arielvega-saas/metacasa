import SwiftUI

struct TransactionListView: View {
    @Environment(AppState.self) private var appState
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    var filtered: [Transaction] {
        guard !searchText.isEmpty else { return transactions }
        return transactions.filter { tx in
            tx.category.localizedCaseInsensitiveContains(searchText) ||
            (tx.note ?? "").localizedCaseInsensitiveContains(searchText) ||
            (tx.subcategory ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else if transactions.isEmpty {
                        ContentUnavailableView(
                            "Aún no hay movimientos",
                            systemImage: "tray",
                            description: Text("Agregá tu primer gasto o ingreso desde la pestaña +")
                        )
                    } else {
                        List {
                            ForEach(groupedByDay.keys.sorted(by: >), id: \.self) { day in
                                Section {
                                    ForEach(groupedByDay[day] ?? []) { tx in
                                        TransactionRow(transaction: tx, currency: householdCurrency)
                                            .listRowBackground(Color.clear)
                                    }
                                    .onDelete { indexSet in
                                        Task { await delete(at: indexSet, in: day) }
                                    }
                                } header: {
                                    Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                                        .font(.mcLabel)
                                        .foregroundStyle(Color.textMuted)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Movimientos")
            .searchable(text: $searchText, prompt: "Buscar por categoría o nota")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private var groupedByDay: [Date: [Transaction]] {
        let cal = Calendar.current
        return Dictionary(grouping: filtered) { tx in
            cal.startOfDay(for: tx.date)
        }
    }

    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let cal = Calendar.current
            let start = cal.date(byAdding: .month, value: -3, to: Date())!
            transactions = try await TransactionService.shared.fetchForPeriod(
                householdId: hid, from: start, to: Date(), limit: 500
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at indexSet: IndexSet, in day: Date) async {
        let items = groupedByDay[day] ?? []
        for i in indexSet {
            guard i < items.count else { continue }
            try? await TransactionService.shared.delete(id: items[i].id)
        }
        await load()
    }
}
