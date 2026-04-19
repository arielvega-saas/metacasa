import SwiftUI

struct RecurringListView: View {
    @Environment(AppState.self) private var appState
    @State private var items: [RecurringTransaction] = []
    @State private var isLoading = true
    @State private var showAdd = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "Sin gastos recurrentes",
                        systemImage: "arrow.triangle.2.circlepath",
                        description: Text("Agregá tus gastos fijos mensuales (alquiler, servicios, suscripciones).")
                    )
                } else {
                    List {
                        ForEach(items) { r in
                            rowView(r).listRowBackground(Color.clear)
                        }
                        .onDelete { idx in Task { await delete(idx) } }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Recurrentes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddRecurringView { await load() }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private func rowView(_ r: RecurringTransaction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: r.frequency.systemIcon)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 36, height: 36)
                .background(Color.brandPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(r.note?.isEmpty == false ? r.note! : r.category)
                    .font(.mcBody.weight(.bold)).foregroundStyle(Color.textPrimary)
                HStack(spacing: 6) {
                    Text(r.frequency.label).font(.mcCaption).foregroundStyle(Color.textMuted)
                    if let nd = r.nextDate {
                        Text("· próximo \(nd.formatted(date: .abbreviated, time: .omitted))")
                            .font(.mcCaption).foregroundStyle(Color.textMuted)
                    }
                }
            }
            Spacer()
            AmountLabel(amount: r.amount, currency: currency, kind: r.type == .gasto ? .gasto : .ingreso)
                .font(.mcBody.weight(.bold))
        }
        .padding(.vertical, 6)
    }

    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await RecurringService.shared.fetchAll(householdId: hid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ indexSet: IndexSet) async {
        for i in indexSet {
            try? await RecurringService.shared.delete(id: items[i].id)
        }
        await load()
    }
}
