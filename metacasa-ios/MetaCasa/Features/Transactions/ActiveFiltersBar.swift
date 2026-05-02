import SwiftUI

/// Barra horizontal scrollable con los filtros actualmente activos.
/// Cada chip es dismissible (tap → remueve ese filtro).
///
/// UX: se muestra solo si hay filtros activos. Aparece con spring animation
/// desde arriba. Inspirado en el patrón de iOS Mail / Files para filtros.
struct ActiveFiltersBar: View {
    @Binding var filters: TransactionFilters
    let accounts: [Account]

    var body: some View {
        if filters.hasAnyFilter {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if filters.typeFilter != .all {
                        chip(
                            label: LocalizedStringKey(filters.typeFilter.localizationKey),
                            icon: filters.typeFilter == .gasto ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                        ) {
                            filters.typeFilter = .all
                        }
                    }
                    if filters.dateFilter != .currentMonth {
                        chip(
                            label: LocalizedStringKey(filters.dateFilter.label),
                            icon: "calendar"
                        ) {
                            filters.dateFilter = .currentMonth
                        }
                    }
                    if filters.amountMin != nil || filters.amountMax != nil {
                        chip(
                            label: amountChipLabel,
                            icon: "dollarsign.circle"
                        ) {
                            filters.amountMin = nil
                            filters.amountMax = nil
                        }
                    }
                    ForEach(Array(filters.selectedCategories), id: \.self) { cat in
                        chip(
                            label: LocalizedStringKey(cat),
                            icon: "tag"
                        ) {
                            filters.selectedCategories.remove(cat)
                        }
                    }
                    ForEach(Array(filters.selectedSubcategories), id: \.self) { sub in
                        chip(
                            label: LocalizedStringKey(sub),
                            icon: "tag.circle"
                        ) {
                            filters.selectedSubcategories.remove(sub)
                        }
                    }
                    ForEach(Array(filters.selectedAccountIds), id: \.self) { id in
                        if let acc = accounts.first(where: { $0.id == id }) {
                            chip(
                                label: LocalizedStringKey(acc.name),
                                icon: "wallet.pass"
                            ) {
                                filters.selectedAccountIds.remove(id)
                            }
                        }
                    }
                    if !filters.searchText.isEmpty {
                        chip(
                            label: LocalizedStringKey("“\(filters.searchText)”"),
                            icon: "magnifyingglass"
                        ) {
                            filters.searchText = ""
                        }
                    }
                    // "Limpiar todo" al final cuando hay ≥ 2 filtros
                    if filters.activeCount >= 2 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                filters = TransactionFilters()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("filters.clearAll")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.brandDanger)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.brandDanger.opacity(0.12))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var amountChipLabel: LocalizedStringKey {
        switch (filters.amountMin, filters.amountMax) {
        case (let mn?, let mx?):
            return LocalizedStringKey("\(Money.format(mn, currency: "", style: .compact)) – \(Money.format(mx, currency: "", style: .compact))")
        case (let mn?, nil):
            return LocalizedStringKey("≥ \(Money.format(mn, currency: "", style: .compact))")
        case (nil, let mx?):
            return LocalizedStringKey("≤ \(Money.format(mx, currency: "", style: .compact))")
        default:
            return ""
        }
    }

    private func chip(
        label: LocalizedStringKey,
        icon: String,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(label).font(.caption.weight(.medium)).lineLimit(1)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onRemove()
                }
            }) {
                Image(systemName: "xmark").font(.caption2.bold())
                    .padding(3)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.white)
        .padding(.leading, 10).padding(.trailing, 4).padding(.vertical, 6)
        .background(Color.brandPrimary)
        .cornerRadius(14)
    }
}
