import SwiftUI

/// Lista de vencimientos (bills).
/// Port de BillCard del web. Agrupa por urgencia con color-coded headers.
struct BillsListView: View {
    @Environment(AppState.self) private var appState
    @State private var bills: [Bill] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAdd = false
    @State private var editing: Bill?

    private var grouped: [(urgency: Bill.UrgencyLevel, bills: [Bill])] {
        let order: [Bill.UrgencyLevel] = [.overdue, .dueToday, .dueSoon, .upcoming, .future, .paid, .skipped]
        return order.compactMap { u in
            let matches = bills.filter { $0.urgency == u }
            return matches.isEmpty ? nil : (u, matches)
        }
    }

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if isLoading && bills.isEmpty {
                    ProgressView().tint(.white)
                } else if bills.isEmpty {
                    ContentUnavailableView(
                        String(localized: "bills.empty.title"),
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("bills.empty.hint")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.urgency) { group in
                            Section {
                                ForEach(group.bills) { bill in
                                    Button { editing = bill } label: {
                                        BillRow(bill: bill, currency: currency)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .leading) {
                                        if bill.status == .pending {
                                            Button {
                                                Task { await markPaid(bill) }
                                            } label: {
                                                Label("bills.markPaid", systemImage: "checkmark.circle.fill")
                                            }
                                            .tint(.green)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await deleteBill(bill) }
                                        } label: {
                                            Label("action.delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    urgencyBadge(group.urgency)
                                    Spacer()
                                    Text("\(group.bills.count)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(Text("more.bills"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddBillView { await load() }
        }
        .sheet(item: $editing) { bill in
            AddBillView(editing: bill) { await load() }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func urgencyBadge(_ u: Bill.UrgencyLevel) -> some View {
        let (color, label): (Color, LocalizedStringKey) = {
            switch u {
            case .overdue:  return (.brandDanger,  "bills.urgency.overdue")
            case .dueToday: return (.brandDanger,  "bills.urgency.today")
            case .dueSoon:  return (.brandWarning, "bills.urgency.soon")
            case .upcoming: return (.brandWarning, "bills.urgency.upcoming")
            case .future:   return (.brandPrimary, "bills.urgency.future")
            case .paid:     return (.brandSuccess, "bills.urgency.paid")
            case .skipped:  return (.secondary,    "bills.urgency.skipped")
            }
        }()
        return Text(label)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(6)
    }

    @MainActor
    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            bills = try await BillService.shared.fetchAll(householdId: hid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func markPaid(_ bill: Bill) async {
        try? await BillService.shared.markPaid(id: bill.id)
        await load()
    }

    @MainActor
    private func deleteBill(_ bill: Bill) async {
        try? await BillService.shared.delete(id: bill.id)
        await load()
    }
}

// MARK: - BillRow

struct BillRow: View {
    @Environment(\.locale) private var locale
    let bill: Bill
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.title)
                    .font(.mcBody.weight(.semibold))
                    .lineLimit(1)
                Text(bill.dueDate, format: .dateTime.day().month(.wide).year())
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
                if bill.status == .pending {
                    daysText.font(.caption2).foregroundStyle(iconColor)
                }
            }

            Spacer()

            AmountLabel(amount: bill.amount, currency: bill.currency, kind: .gasto)
                .font(.mcBody.weight(.bold))
        }
        .padding(.vertical, 10)
    }

    private var iconName: String {
        switch bill.urgency {
        case .paid: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .dueToday: return "clock.fill"
        case .dueSoon: return "clock.badge.exclamationmark"
        case .upcoming: return "calendar"
        case .future: return "calendar.badge.plus"
        case .skipped: return "minus.circle.fill"
        }
    }

    private var iconColor: Color {
        switch bill.urgency {
        case .paid: return .brandSuccess
        case .overdue, .dueToday: return .brandDanger
        case .dueSoon, .upcoming: return .brandWarning
        case .future: return .brandPrimary
        case .skipped: return .secondary
        }
    }

    @ViewBuilder
    private var daysText: some View {
        let days = bill.daysUntilDue
        if days < 0 {
            Text("bills.days.overdue \(-days)")
        } else if days == 0 {
            Text("bills.days.today")
        } else {
            Text("bills.days.in \(days)")
        }
    }
}
