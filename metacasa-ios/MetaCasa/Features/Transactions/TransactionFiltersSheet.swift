import SwiftUI

/// Hoja de filtros avanzados para Movimientos.
///
/// UX: `DisclosureGroup`s apilados en `Form` — patrón nativo iOS que mantiene
/// la interfaz minimalista (cada sección se expande solo cuando se usa).
/// Respecta la paridad funcional con la PWA pero aprovecha:
/// - Segmented Pickers (para selección corta)
/// - DatePickers inline con estilo graphical cuando corresponde
/// - Chips de categoría/cuenta con toggle visual (tap = select/deselect)
/// - presentationDetents [.medium, .large] para que el usuario elija espacio
struct TransactionFiltersSheet: View {
    @Binding var filters: TransactionFilters
    let availableAccounts: [Account]
    let availableCategories: [CategoryItem]
    @Environment(\.dismiss) private var dismiss

    // Expansión local de cada sección. Todas cerradas por default para
    // minimalismo; se abren solo las secciones que el usuario tocó.
    @State private var expandedType: Bool = false
    @State private var expandedDate: Bool = false
    @State private var expandedAmount: Bool = false
    @State private var expandedCategories: Bool = false
    @State private var expandedSubcategories: Bool = false
    @State private var expandedAccounts: Bool = false
    @State private var expandedMode: Bool = false

    // Staging local de entradas numéricas (bind a TextField requiere String).
    @State private var amountMinStr: String = ""
    @State private var amountMaxStr: String = ""

    // Staging de fechas para "specificMonth" y "range"
    @State private var specificMonthDate: Date = Date()
    @State private var rangeFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var rangeTo: Date = Date()
    @State private var singleDay: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                sectionType
                sectionDate
                sectionAmount
                sectionCategories
                if !availableSubcategories.isEmpty {
                    sectionSubcategories
                }
                sectionAccounts
                sectionMode
            }
            .navigationTitle(Text("filters.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        filters = TransactionFilters()
                    } label: {
                        Text("filters.reset")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: syncFromFilters)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var sectionType: some View {
        DisclosureGroup(isExpanded: $expandedType) {
            Picker("", selection: $filters.typeFilter) {
                ForEach(TransactionFilters.TypeFilter.allCases) { t in
                    Text(LocalizedStringKey(t.localizationKey)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } label: {
            rowHeader(
                title: "filters.type",
                systemImage: "line.3.horizontal.decrease.circle",
                value: LocalizedStringKey(filters.typeFilter.localizationKey),
                isActive: filters.typeFilter != .all
            )
        }
    }

    private var sectionDate: some View {
        DisclosureGroup(isExpanded: $expandedDate) {
            VStack(alignment: .leading, spacing: 12) {
                // Chips con cada preset
                FlowLayout(spacing: 6) {
                    datePresetChip(.currentMonth, label: "filters.date.currentMonth")
                    datePresetChip(.lastMonth, label: "filters.date.lastMonth")
                    datePresetChip(.thisWeek, label: "filters.date.thisWeek")
                    datePresetChip(.allTime, label: "filters.date.allTime")
                }

                // Opciones avanzadas con sub-pickers
                VStack(alignment: .leading, spacing: 10) {
                    // Mes específico
                    Button {
                        filters.dateFilter = makeSpecificMonth(from: specificMonthDate)
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("filters.date.specificMonth")
                            Spacer()
                            DatePicker(
                                "",
                                selection: $specificMonthDate,
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .onChange(of: specificMonthDate) { _, newDate in
                                if case .specificMonth = filters.dateFilter {
                                    filters.dateFilter = makeSpecificMonth(from: newDate)
                                }
                            }
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(chipBg(active: isSpecificMonthActive))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // Día único
                    HStack {
                        Image(systemName: "calendar.circle")
                        Text("filters.date.singleDay")
                        Spacer()
                        DatePicker(
                            "",
                            selection: $singleDay,
                            displayedComponents: [.date]
                        )
                        .labelsHidden()
                        .onChange(of: singleDay) { _, newValue in
                            filters.dateFilter = .singleDay(newValue)
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(chipBg(active: isSingleDayActive))
                    .cornerRadius(10)

                    // Rango
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("filters.date.range")
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            DatePicker("export.from", selection: $rangeFrom, displayedComponents: .date)
                                .onChange(of: rangeFrom) { _, _ in
                                    filters.dateFilter = .range(from: rangeFrom, to: rangeTo)
                                }
                            DatePicker("export.to", selection: $rangeTo, displayedComponents: .date)
                                .onChange(of: rangeTo) { _, _ in
                                    filters.dateFilter = .range(from: rangeFrom, to: rangeTo)
                                }
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(chipBg(active: isRangeActive))
                    .cornerRadius(10)
                }
            }
            .padding(.vertical, 4)
        } label: {
            rowHeader(
                title: "filters.date",
                systemImage: "calendar",
                value: LocalizedStringKey(filters.dateFilter.label),
                isActive: filters.dateFilter != .currentMonth
            )
        }
    }

    private var sectionAmount: some View {
        DisclosureGroup(isExpanded: $expandedAmount) {
            VStack(spacing: 10) {
                HStack {
                    Text("filters.amount.min").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    TextField("0", text: $amountMinStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                        .onChange(of: amountMinStr) { _, new in
                            filters.amountMin = Money.parse(new)
                        }
                }
                HStack {
                    Text("filters.amount.max").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    TextField("∞", text: $amountMaxStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                        .onChange(of: amountMaxStr) { _, new in
                            filters.amountMax = Money.parse(new)
                        }
                }
            }
        } label: {
            rowHeader(
                title: "filters.amount",
                systemImage: "dollarsign.circle",
                value: amountSummary,
                isActive: filters.amountMin != nil || filters.amountMax != nil
            )
        }
    }

    private var sectionCategories: some View {
        DisclosureGroup(isExpanded: $expandedCategories) {
            if availableCategories.isEmpty {
                Text("filters.categories.none")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(availableCategories, id: \.name) { cat in
                        categoryChip(cat)
                    }
                }
                if !filters.selectedCategories.isEmpty {
                    Button {
                        filters.selectedCategories = []
                    } label: {
                        Text("filters.categories.clear")
                            .font(.caption)
                    }
                }
            }
        } label: {
            rowHeader(
                title: "filters.categories",
                systemImage: "tag",
                value: categoriesSummary,
                isActive: !filters.selectedCategories.isEmpty
            )
        }
    }

    /// Lista plana de subcategorías disponibles según el contexto:
    /// - Si hay categorías seleccionadas → solo las subcategorías de esas.
    /// - Si no hay nada seleccionado → todas las subcategorías conocidas.
    /// Dedup + sort alfabético para mostrar consistente.
    private var availableSubcategories: [(parent: String, name: String)] {
        let targetParents: [CategoryItem]
        if filters.selectedCategories.isEmpty {
            targetParents = availableCategories
        } else {
            targetParents = availableCategories.filter {
                filters.selectedCategories.contains($0.name)
            }
        }
        var pairs: [(parent: String, name: String)] = []
        var seen: Set<String> = []
        for cat in targetParents {
            for sub in (cat.subcategories ?? []) where !sub.isEmpty && !seen.contains(sub) {
                seen.insert(sub)
                pairs.append((parent: cat.name, name: sub))
            }
        }
        return pairs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var sectionSubcategories: some View {
        DisclosureGroup(isExpanded: $expandedSubcategories) {
            FlowLayout(spacing: 6) {
                ForEach(availableSubcategories, id: \.name) { pair in
                    subcategoryChip(name: pair.name, parent: pair.parent)
                }
            }
            if !filters.selectedSubcategories.isEmpty {
                Button {
                    filters.selectedSubcategories = []
                } label: {
                    Text("filters.subcategories.clear")
                        .font(.caption)
                }
            }
        } label: {
            rowHeader(
                title: "filters.subcategories",
                systemImage: "tag.circle",
                value: subcategoriesSummary,
                isActive: !filters.selectedSubcategories.isEmpty
            )
        }
    }

    private func subcategoryChip(name: String, parent: String) -> some View {
        let selected = filters.selectedSubcategories.contains(name)
        return Button {
            if selected { filters.selectedSubcategories.remove(name) }
            else { filters.selectedSubcategories.insert(name) }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.caption.weight(.semibold))
                Text(parent).font(.caption2).foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(chipBg(active: selected))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private var subcategoriesSummary: LocalizedStringKey {
        let n = filters.selectedSubcategories.count
        return n == 0 ? "filters.all" : "\(n)"
    }

    private var sectionAccounts: some View {
        DisclosureGroup(isExpanded: $expandedAccounts) {
            if availableAccounts.isEmpty {
                Text("filters.accounts.none")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 6) {
                    // Include "Sin cuenta (hogar)" toggle
                    Toggle(isOn: $filters.includeNoAccount) {
                        Label {
                            Text("filters.accounts.noAccount")
                        } icon: {
                            Image(systemName: "house.fill")
                        }
                    }
                    .font(.subheadline)

                    Divider()

                    ForEach(availableAccounts) { acc in
                        accountRow(acc)
                    }
                }
                if !filters.selectedAccountIds.isEmpty {
                    Button {
                        filters.selectedAccountIds = []
                    } label: {
                        Text("filters.accounts.clear")
                            .font(.caption)
                    }
                }
            }
        } label: {
            rowHeader(
                title: "filters.accounts",
                systemImage: "wallet.pass",
                value: accountsSummary,
                isActive: !filters.selectedAccountIds.isEmpty
            )
        }
    }

    private var sectionMode: some View {
        DisclosureGroup(isExpanded: $expandedMode) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $filters.dateMode) {
                    ForEach(TransactionFilters.DateMode.allCases, id: \.self) { m in
                        Text(LocalizedStringKey(m.localizationKey)).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                Text("filters.mode.hint")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } label: {
            rowHeader(
                title: "filters.mode",
                systemImage: "calendar.day.timeline.left",
                value: LocalizedStringKey(filters.dateMode.localizationKey),
                isActive: filters.dateMode != .real
            )
        }
    }

    // MARK: - Sub-pieces

    private func rowHeader(
        title: LocalizedStringKey,
        systemImage: String,
        value: LocalizedStringKey,
        isActive: Bool
    ) -> some View {
        HStack {
            Label {
                Text(title)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(isActive ? Color.brandPrimary : .secondary)
            }
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(isActive ? Color.brandPrimary : .secondary)
        }
    }

    private func datePresetChip(_ preset: TransactionFilters.DateFilter, label: LocalizedStringKey) -> some View {
        Button {
            filters.dateFilter = preset
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(chipBg(active: filters.dateFilter == preset))
                .foregroundStyle(filters.dateFilter == preset ? Color.white : Color.primary)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func categoryChip(_ cat: CategoryItem) -> some View {
        let selected = filters.selectedCategories.contains(cat.name)
        return Button {
            if selected { filters.selectedCategories.remove(cat.name) }
            else { filters.selectedCategories.insert(cat.name) }
        } label: {
            HStack(spacing: 4) {
                Text(cat.emoji ?? "•")
                Text(cat.name).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(chipBg(active: selected))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func accountRow(_ acc: Account) -> some View {
        let selected = filters.selectedAccountIds.contains(acc.id)
        return Button {
            if selected { filters.selectedAccountIds.remove(acc.id) }
            else { filters.selectedAccountIds.insert(acc.id) }
        } label: {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.brandPrimary : .secondary)
                Text(acc.name)
                Spacer()
                Text(acc.type.label).font(.caption2).foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chipBg(active: Bool) -> Color {
        active ? Color.brandPrimary : Color(.secondarySystemFill)
    }

    // MARK: - Summaries

    private var amountSummary: LocalizedStringKey {
        switch (filters.amountMin, filters.amountMax) {
        case (nil, nil): return "filters.amount.any"
        case (let mn?, nil): return LocalizedStringKey("≥ \(Money.format(mn, currency: "", style: .compact))")
        case (nil, let mx?): return LocalizedStringKey("≤ \(Money.format(mx, currency: "", style: .compact))")
        case (let mn?, let mx?):
            return LocalizedStringKey("\(Money.format(mn, currency: "", style: .compact)) – \(Money.format(mx, currency: "", style: .compact))")
        }
    }

    private var categoriesSummary: LocalizedStringKey {
        let n = filters.selectedCategories.count
        return n == 0 ? "filters.all" : "\(n)"
    }

    private var accountsSummary: LocalizedStringKey {
        let n = filters.selectedAccountIds.count
        return n == 0 ? "filters.all" : "\(n)"
    }

    // MARK: - Helpers

    private func makeSpecificMonth(from date: Date) -> TransactionFilters.DateFilter {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return .specificMonth(year: comps.year ?? 2026, month: comps.month ?? 1)
    }

    private var isSpecificMonthActive: Bool {
        if case .specificMonth = filters.dateFilter { return true }
        return false
    }
    private var isSingleDayActive: Bool {
        if case .singleDay = filters.dateFilter { return true }
        return false
    }
    private var isRangeActive: Bool {
        if case .range = filters.dateFilter { return true }
        return false
    }

    private func syncFromFilters() {
        if let mn = filters.amountMin { amountMinStr = "\(mn)" }
        if let mx = filters.amountMax { amountMaxStr = "\(mx)" }
        switch filters.dateFilter {
        case .specificMonth(let y, let m):
            var comps = DateComponents(); comps.year = y; comps.month = m
            specificMonthDate = Calendar.current.date(from: comps) ?? Date()
        case .singleDay(let d):
            singleDay = d
        case .range(let from, let to):
            rangeFrom = from; rangeTo = to
        default:
            break
        }
    }
}

// MARK: - FlowLayout

/// Layout tipo "flow" que envuelve chips en múltiples líneas.
/// Nativo en SwiftUI 16+ via el `Layout` protocol — nos evita `LazyVGrid`
/// con celdas fijas que quedaría feo para chips de ancho variable.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
