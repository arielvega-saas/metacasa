import SwiftUI

/// Botón que muestra la moneda seleccionada y abre un picker al tocar.
/// Uso:
/// ```
/// @State var code = "USD"
/// CurrencyPickerButton(selectedCode: $code)
/// ```
struct CurrencyPickerButton: View {
    @Binding var selectedCode: String
    var label: String = "Moneda"
    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 10) {
                if let info = CurrenciesCatalog.info(for: selectedCode) {
                    Text(info.flag).font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(info.name).foregroundStyle(.primary)
                            Text("· \(info.code)").foregroundStyle(.secondary)
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                } else {
                    Text("Elegir moneda").foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            CurrencyPickerSheet(selectedCode: $selectedCode)
        }
    }
}

/// Sheet con lista agrupada por región + searchable.
struct CurrencyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCode: String
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    ForEach(CurrenciesCatalog.byRegion, id: \.0) { group in
                        Section(group.0.rawValue) {
                            ForEach(group.1) { c in
                                row(c)
                            }
                        }
                    }
                } else {
                    let filtered = CurrenciesCatalog.all.filter { c in
                        c.name.localizedCaseInsensitiveContains(search) ||
                        c.code.localizedCaseInsensitiveContains(search) ||
                        c.shortName.localizedCaseInsensitiveContains(search)
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else {
                        ForEach(filtered) { c in
                            row(c)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Buscar moneda o código")
            .navigationTitle("Moneda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func row(_ c: CurrencyInfo) -> some View {
        Button {
            selectedCode = c.code
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(c.flag).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(c.code).font(.system(size: 12, weight: .bold)).foregroundStyle(.tertiary)
                        Text("·").foregroundStyle(.tertiary)
                        Text(c.symbol).font(.system(size: 12, weight: .medium).monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selectedCode == c.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
