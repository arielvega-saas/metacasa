import SwiftUI

/// Pantalla para gestionar tasas manuales de cambio.
/// Port del feature `exchangeRates` del web (App.jsx:157-179).
///
/// UX:
/// - Lista actual de tasas (moneda → rate → última actualización)
/// - Botón `+` para agregar/editar (picker de moneda + input)
/// - Swipe-to-delete
/// - Privacy-sensitive: respeta PrivacyManager para ocultar los números
struct FXRatesView: View {
    @Environment(AppState.self) private var appState
    @State private var rates: FXRateMap = [:]
    @State private var showAdd = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if isLoading && rates.isEmpty {
                    ProgressView().tint(.white)
                } else if rates.isEmpty {
                    ContentUnavailableView(
                        String(localized: "fx.empty.title"),
                        systemImage: "dollarsign.arrow.circlepath",
                        description: Text("fx.empty.hint \(householdCurrency)")
                    )
                } else {
                    List {
                        Section {
                            ForEach(sortedRates, id: \.currency) { entry in
                                HStack {
                                    Text(entry.currency)
                                        .font(.body.weight(.bold))
                                        .frame(width: 50, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text("1")
                                            Text(entry.currency)
                                            Text("=")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        Text("\(Money.format(entry.rate, currency: householdCurrency, style: .auto)) ")
                                            .font(.body.weight(.semibold))
                                    }
                                    Spacer()
                                    if let date = parseDate(entry.updatedAt) {
                                        Text(date, format: .dateTime.day().month(.abbreviated))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await remove(currency: entry.currency) }
                                    } label: {
                                        Label("action.delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("fx.list.header")
                                Spacer()
                                Text("fx.base \(householdCurrency)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.brandPrimary)
                            }
                        } footer: {
                            Text("fx.list.hint")
                                .font(.caption2)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(Text("settings.fxRates"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddFXRateSheet(
                householdCurrency: householdCurrency,
                existingCurrencies: Set(rates.keys),
                onSaved: { currency, rate in
                    Task { await set(currency: currency, rate: rate) }
                }
            )
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private struct RateEntry {
        let currency: String
        let rate: Decimal
        let updatedAt: String
    }

    private var sortedRates: [RateEntry] {
        rates.map { (c, r) in RateEntry(currency: c, rate: r.rate, updatedAt: r.updatedAt) }
            .sorted { $0.currency < $1.currency }
    }

    private func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    @MainActor
    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        rates = (try? await FXService.shared.fetch(householdId: hid)) ?? [:]
    }

    @MainActor
    private func set(currency: String, rate: Decimal) async {
        guard let hid = appState.currentHouseholdId else { return }
        do {
            try await FXService.shared.setRate(householdId: hid, currency: currency, rate: rate)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func remove(currency: String) async {
        guard let hid = appState.currentHouseholdId else { return }
        try? await FXService.shared.removeRate(householdId: hid, currency: currency)
        await load()
    }
}

// MARK: - Add sheet

private struct AddFXRateSheet: View {
    let householdCurrency: String
    let existingCurrencies: Set<String>
    let onSaved: (String, Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCurrency: String = "USD"
    @State private var rateStr: String = ""

    private let popular = ["USD", "EUR", "GBP", "BRL", "ARS", "MXN", "CLP", "COP", "PEN", "UYU", "JPY", "CAD"]

    var body: some View {
        NavigationStack {
            Form {
                Section("fx.add.currency") {
                    Picker("fx.add.currency", selection: $selectedCurrency) {
                        ForEach(popular.filter { $0 != householdCurrency }, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    if existingCurrencies.contains(selectedCurrency) {
                        Text("fx.add.willReplace")
                            .font(.caption)
                            .foregroundStyle(Color.brandWarning)
                    }
                }
                Section("fx.add.rate") {
                    HStack {
                        Text("1")
                        Text(selectedCurrency).font(.body.weight(.bold))
                        Text("=")
                        TextField("0", text: $rateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(householdCurrency).foregroundStyle(.secondary)
                    }
                    Text("fx.add.hint \(selectedCurrency) \(householdCurrency)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Text("fx.add.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        if let r = Money.parse(rateStr), r > 0 {
                            onSaved(selectedCurrency, r)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled((Money.parse(rateStr) ?? 0) <= 0)
                }
            }
        }
    }
}
