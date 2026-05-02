import SwiftUI
import Charts

/// Compara dos meses lado a lado: totales (ingresos/gastos/balance) y top
/// categorías de gasto. Port del `CompareModal` de la PWA (App.jsx:2392+).
@MainActor
struct CompareMonthsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var monthA: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var monthB: Date = Date()

    @State private var txsA: [Transaction] = []
    @State private var txsB: [Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    pickersCard
                    if isLoading {
                        ProgressView().padding()
                    } else {
                        totalsCard
                        topCategoriesCard
                    }
                    if let msg = errorMessage {
                        Text(msg).font(.mcCaption).foregroundStyle(Color.brandDanger)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .navigationTitle(Text("Comparar meses"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task { await reload() }
            .onChange(of: monthA) { _, _ in Task { await reload() } }
            .onChange(of: monthB) { _, _ in Task { await reload() } }
        }
    }

    // MARK: - Sections

    private var pickersCard: some View {
        VStack(spacing: 12) {
            monthPicker(titleKey: "compare.monthA", selection: $monthA, accent: Color.brandSecondary)
            monthPicker(titleKey: "compare.monthB", selection: $monthB, accent: Color.brandPrimary)
        }
        .mcCard()
    }

    private func monthPicker(titleKey: LocalizedStringKey, selection: Binding<Date>, accent: Color) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(accent)
            Text(titleKey).font(.mcLabel).foregroundStyle(Color.textMuted)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: [.date])
                .labelsHidden()
        }
    }

    private var totalsCard: some View {
        let (ingA, gasA) = totals(txs: txsA)
        let (ingB, gasB) = totals(txs: txsB)
        let balA = ingA - gasA
        let balB = ingB - gasB
        return VStack(spacing: 14) {
            HStack {
                Text("compare.totals").font(.mcH2).foregroundStyle(Color.textPrimary)
                Spacer()
            }
            compareRow(labelKey: "compare.income", valueA: ingA, valueB: ingB, kind: .ingreso)
            Divider()
            compareRow(labelKey: "compare.expenses", valueA: gasA, valueB: gasB, kind: .gasto)
            Divider()
            compareRow(labelKey: "compare.balance", valueA: balA, valueB: balB, kind: .balance)
        }
        .mcCard()
    }

    private func compareRow(labelKey: LocalizedStringKey, valueA: Decimal, valueB: Decimal, kind: AmountLabel.Kind) -> some View {
        let delta = valueB - valueA
        return VStack(alignment: .leading, spacing: 6) {
            Text(labelKey).font(.mcLabel).foregroundStyle(Color.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("compare.monthA").font(.caption2).foregroundStyle(.secondary)
                    AmountLabel(amount: valueA, currency: householdCurrency, kind: kind)
                        .font(.mcSerifInline)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("compare.monthB").font(.caption2).foregroundStyle(.secondary)
                    AmountLabel(amount: valueB, currency: householdCurrency, kind: kind)
                        .font(.mcSerifInline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Δ").font(.caption2).foregroundStyle(.secondary)
                    Text(deltaLabel(delta: delta, kind: kind))
                        .font(.mcSerifInline)
                        .foregroundStyle(deltaColor(delta: delta, kind: kind))
                }
            }
        }
    }

    private func deltaLabel(delta: Decimal, kind: AmountLabel.Kind) -> String {
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(Money.format(delta, currency: householdCurrency, style: .compact))"
    }

    private func deltaColor(delta: Decimal, kind: AmountLabel.Kind) -> Color {
        // Para gastos, subir es malo (rojo), bajar es bueno (verde).
        // Para ingresos y balance, al revés.
        let isImprovement: Bool
        switch kind {
        case .gasto:   isImprovement = delta < 0
        default:       isImprovement = delta > 0
        }
        if delta == 0 { return Color.textMuted }
        return isImprovement ? Color.brandSuccess : Color.brandDanger
    }

    private var topCategoriesCard: some View {
        let byCatA = groupByCategory(txs: txsA, type: .gasto)
        let byCatB = groupByCategory(txs: txsB, type: .gasto)
        let allCats = Array(Set(byCatA.keys).union(byCatB.keys))
        let rows = allCats
            .map { cat in
                (category: cat, a: byCatA[cat] ?? 0, b: byCatB[cat] ?? 0)
            }
            .sorted { max($0.a, $0.b) > max($1.a, $1.b) }
            .prefix(8)

        let monthALabel = String(localized: "compare.monthA")
        let monthBLabel = String(localized: "compare.monthB")
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("compare.categories").font(.mcH2).foregroundStyle(Color.textPrimary)
                Spacer()
            }

            if rows.isEmpty {
                Text("compare.noData")
                    .font(.mcBody).foregroundStyle(Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Chart {
                    ForEach(Array(rows), id: \.category) { row in
                        BarMark(
                            x: .value("Monto", (row.a as NSDecimalNumber).doubleValue),
                            y: .value("Categoría", row.category)
                        )
                        .foregroundStyle(by: .value("Mes", monthALabel))
                        .position(by: .value("Mes", monthALabel))

                        BarMark(
                            x: .value("Monto", (row.b as NSDecimalNumber).doubleValue),
                            y: .value("Categoría", row.category)
                        )
                        .foregroundStyle(by: .value("Mes", monthBLabel))
                        .position(by: .value("Mes", monthBLabel))
                    }
                }
                .chartForegroundStyleScale([
                    monthALabel: Color.brandSecondary,
                    monthBLabel: Color.brandPrimary
                ])
                .frame(height: CGFloat(rows.count) * 38 + 30)
            }
        }
        .mcCard()
    }

    // MARK: - Data

    private func reload() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        guard let hid = appState.currentHouseholdId else { return }
        do {
            let rA = monthRange(date: monthA)
            let rB = monthRange(date: monthB)
            async let a = TransactionService.shared.fetchForPeriod(householdId: hid, from: rA.from, to: rA.to, limit: 5000)
            async let b = TransactionService.shared.fetchForPeriod(householdId: hid, from: rB.from, to: rB.to, limit: 5000)
            txsA = try await a
            txsB = try await b
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func monthRange(date: Date) -> (from: Date, to: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        let start = cal.date(from: comps) ?? date
        let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59), to: start) ?? date
        return (start, end)
    }

    private func totals(txs: [Transaction]) -> (ingresos: Decimal, gastos: Decimal) {
        let ing = txs.filter { $0.type == .ingreso }.reduce(Decimal(0)) { $0 + $1.amount }
        let gas = txs.filter { $0.type == .gasto }.reduce(Decimal(0)) { $0 + $1.amount }
        return (ing, gas)
    }

    private func groupByCategory(txs: [Transaction], type: TxType) -> [String: Decimal] {
        var result: [String: Decimal] = [:]
        for tx in txs where tx.type == type {
            result[tx.category, default: 0] += tx.amount
        }
        return result
    }
}
