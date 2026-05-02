import SwiftUI

/// Vista principal de Movimientos.
///
/// Features (paridad con MetaCasa web + mejoras iOS-native):
/// - Filtros completos (tipo, fecha, monto, categoría, cuenta, modo, search)
///   en una sheet con DisclosureGroups
/// - Chips de filtros activos scrolleables (dismiss con tap)
/// - Sort menu (fecha/monto asc/desc) en toolbar
/// - Vista lista o calendario heatmap (swipe para cambiar mes)
/// - Export / Import en menú ellipsis
/// - Search nativa iOS (searchable)
struct TransactionListView: View {
    @Environment(AppState.self) private var appState

    // Raw data
    @State private var transactions: [Transaction] = []
    @State private var accounts: [Account] = []
    @State private var categoriesBlob: CategoriesBlob?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Filtros + UI state
    @State private var filters = TransactionFilters()
    @State private var viewMode: TransactionViewMode = .list
    @State private var showFilters = false
    @State private var editingTx: Transaction?
    @State private var showExport = false
    @State private var showImport = false
    @State private var selectedDayTxs: DayTransactions?

    /// Identificable wrapper para el sheet de detalle de día del calendario.
    struct DayTransactions: Identifiable {
        let id = UUID()
        let date: Date
        let transactions: [Transaction]
    }

    // MARK: - Derived

    private var filtered: [Transaction] { filters.apply(to: transactions) }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private var availableCategories: [CategoryItem] {
        // Unión gastos + ingresos, dedup por nombre.
        let gastos = CategoryService.merged(custom: categoriesBlob?.data, type: .gasto)
        let ingresos = CategoryService.merged(custom: categoriesBlob?.data, type: .ingreso)
        let all = gastos + ingresos
        var seen = Set<String>()
        return all.filter { seen.insert($0.name).inserted }
    }

    private var groupedByDay: [Date: [Transaction]] {
        let cal = Calendar.current
        return Dictionary(grouping: filtered) { tx in cal.startOfDay(for: tx.date) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // View mode switcher (list / calendar)
                    viewModePicker
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    // Chips de filtros activos
                    ActiveFiltersBar(filters: $filters, accounts: accounts)

                    // Contenido
                    Group {
                        if isLoading && transactions.isEmpty {
                            ProgressView().tint(.white)
                                .frame(maxHeight: .infinity)
                        } else if transactions.isEmpty {
                            ContentUnavailableView(
                                String(localized: "tx.empty.title"),
                                systemImage: "tray",
                                description: Text("tx.empty.hint")
                            )
                        } else if filtered.isEmpty {
                            ContentUnavailableView(
                                String(localized: "tx.empty.filtered"),
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("tx.empty.filtered.hint")
                            )
                        } else {
                            contentForMode
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle(Text("tab.transactions"))
            .searchable(text: $filters.searchText, prompt: Text("tx.list.search"))
            .refreshable { await load() }
            .task { await load() }
            .toolbar { toolbarContent }
            .sheet(item: $editingTx) { tx in
                EditTransactionView(transaction: tx) { await load() }
            }
            .sheet(isPresented: $showFilters) {
                TransactionFiltersSheet(
                    filters: $filters,
                    availableAccounts: accounts,
                    availableCategories: availableCategories
                )
            }
            .sheet(isPresented: $showExport) { ExportTransactionsView() }
            .sheet(isPresented: $showImport) {
                ImportTransactionsView { await load() }
            }
            .sheet(item: $selectedDayTxs) { day in
                DayDetailSheet(
                    date: day.date,
                    transactions: day.transactions,
                    currency: householdCurrency,
                    onTapTx: { tx in
                        selectedDayTxs = nil
                        editingTx = tx
                    }
                )
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: filters)
            .animation(.easeInOut(duration: 0.25), value: viewMode)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showFilters = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                    if filters.activeCount > 0 {
                        Text("\(filters.activeCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.brandPrimary)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -6)
                    }
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                sortSection
                Divider()
                dataSection
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var sortSection: some View {
        Menu {
            ForEach(TransactionFilters.Sort.allCases, id: \.self) { sort in
                Button {
                    filters.sort = sort
                } label: {
                    HStack {
                        Label {
                            Text(LocalizedStringKey(sort.localizationKey))
                        } icon: {
                            Image(systemName: sort.icon)
                        }
                        if filters.sort == sort {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label {
                Text("sort.title")
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }

    private var dataSection: some View {
        Group {
            Button { showExport = true } label: {
                Label {
                    Text("action.export")
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            Button { showImport = true } label: {
                Label {
                    Text("action.import")
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
        }
    }

    // MARK: - Content for mode

    private var viewModePicker: some View {
        HStack {
            Picker("", selection: $viewMode) {
                ForEach(TransactionViewMode.allCases, id: \.self) { mode in
                    Label {
                        Text(LocalizedStringKey(mode.localizationKey))
                    } icon: {
                        Image(systemName: mode.icon)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var contentForMode: some View {
        switch viewMode {
        case .list:
            listView
        case .calendar:
            ScrollView {
                TransactionCalendarView(
                    transactions: filtered,
                    currency: householdCurrency,
                    onTap: { date, txs in
                        selectedDayTxs = DayTransactions(date: date, transactions: txs)
                    }
                )
                .padding(.top, 8)
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(groupedByDay.keys.sorted(by: >), id: \.self) { day in
                Section {
                    ForEach(groupedByDay[day] ?? []) { tx in
                        Button { editingTx = tx } label: {
                            TransactionRow(transaction: tx, currency: householdCurrency)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await deleteTransaction(tx) }
                            } label: {
                                Label("action.delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.mcLabel)
                            .foregroundStyle(Color.textMuted)
                        Spacer()
                        Text("\((groupedByDay[day] ?? []).count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Data

    @MainActor
    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // Traemos más historial para que los filtros tengan data — 12 meses.
            let cal = Calendar.current
            let start = cal.date(byAdding: .month, value: -12, to: Date()) ?? Date()
            async let txs = TransactionService.shared.fetchForPeriod(
                householdId: hid, from: start, to: Date(), limit: 5000
            )
            async let accs = AccountService.shared.fetchAll(householdId: hid)
            async let cats = CategoryService.shared.fetch(householdId: hid)
            transactions = try await txs
            accounts = try await accs
            categoriesBlob = try await cats
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteTransaction(_ tx: Transaction) async {
        try? await TransactionService.shared.delete(id: tx.id)
        await load()
    }
}

// MARK: - DayDetailSheet

/// Sheet que muestra las transacciones de un día elegido en el calendario.
private struct DayDetailSheet: View {
    let date: Date
    let transactions: [Transaction]
    let currency: String
    let onTapTx: (Transaction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(transactions) { tx in
                Button { onTapTx(tx) } label: {
                    TransactionRow(transaction: tx, currency: currency)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle(Text(date, format: .dateTime.weekday(.wide).day().month(.wide)))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
