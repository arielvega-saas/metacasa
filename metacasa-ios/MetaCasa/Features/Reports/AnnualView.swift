import SwiftUI
import Charts

/// Resumen anual: 12 meses en grid con ingresos/gastos/balance + chart comparativo.
/// Port del `AnnualModal` de la PWA (App.jsx:1857+).
@MainActor
struct AnnualView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var monthly: [MonthTotals] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    struct MonthTotals: Identifiable, Sendable {
        let id: Int           // 1..12
        let month: Int
        let ingresos: Decimal
        let gastos: Decimal
        var balance: Decimal { ingresos - gastos }
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    yearPickerCard
                    if isLoading {
                        ProgressView().padding(.vertical, 30)
                    } else {
                        annualTotalsCard
                        chartCard
                        monthsGrid
                    }
                    if let msg = errorMessage {
                        Text(msg).font(.mcCaption).foregroundStyle(Color.brandDanger)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .navigationTitle(Text("Vista anual"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task { await reload() }
            .onChange(of: year) { _, _ in Task { await reload() } }
        }
    }

    // MARK: - Sections

    private var yearPickerCard: some View {
        HStack {
            Button {
                year -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Text(String(year))
                .font(.mcH1)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button {
                if year < Calendar.current.component(.year, from: Date()) + 5 {
                    year += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 40, height: 40)
            }
        }
        .mcCard()
    }

    private var annualTotalsCard: some View {
        let totalIng = monthly.reduce(Decimal(0)) { $0 + $1.ingresos }
        let totalGas = monthly.reduce(Decimal(0)) { $0 + $1.gastos }
        let totalBal = totalIng - totalGas
        return VStack(spacing: 10) {
            HStack {
                totalTile(labelKey: "annual.incomeYear", amount: totalIng, kind: .ingreso)
                totalTile(labelKey: "annual.expensesYear", amount: totalGas, kind: .gasto)
            }
            totalTile(labelKey: "annual.balanceYear", amount: totalBal, kind: .balance, wide: true)
        }
    }

    private func totalTile(labelKey: LocalizedStringKey, amount: Decimal, kind: AmountLabel.Kind, wide: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(labelKey).font(.mcLabel).foregroundStyle(Color.textMuted)
            AmountLabel(amount: amount, currency: householdCurrency, kind: kind)
                .font(.mcSerifAmount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    private var chartCard: some View {
        let incomeLabel = String(localized: "compare.income")
        let expensesLabel = String(localized: "compare.expenses")
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("annual.evolution").font(.mcH2).foregroundStyle(Color.textPrimary)
                Spacer()
            }

            Chart {
                ForEach(monthly) { row in
                    BarMark(
                        x: .value("Mes", monthLabel(row.month)),
                        y: .value("Ingresos", (row.ingresos as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(by: .value("Tipo", incomeLabel))
                    .position(by: .value("Tipo", incomeLabel))

                    BarMark(
                        x: .value("Mes", monthLabel(row.month)),
                        y: .value("Gastos", (row.gastos as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(by: .value("Tipo", expensesLabel))
                    .position(by: .value("Tipo", expensesLabel))
                }
            }
            .chartForegroundStyleScale([
                incomeLabel: Color.brandSuccess,
                expensesLabel: Color.brandDanger
            ])
            .frame(height: 240)
        }
        .mcCard()
    }

    private var monthsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(monthly) { row in
                VStack(alignment: .leading, spacing: 6) {
                    Text(monthLabel(row.month)).font(.mcLabel).foregroundStyle(Color.textMuted)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(Color.brandSuccess)
                            .font(.caption2)
                        Text(Money.format(row.ingresos, currency: householdCurrency, style: .compact))
                            .font(.caption.weight(.semibold))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(Color.brandDanger)
                            .font(.caption2)
                        Text(Money.format(row.gastos, currency: householdCurrency, style: .compact))
                            .font(.caption.weight(.semibold))
                    }
                    AmountLabel(amount: row.balance, currency: householdCurrency, kind: .balance)
                        .font(.caption.weight(.bold))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Data

    private func reload() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        guard let hid = appState.currentHouseholdId else { return }
        let cal = Calendar.current
        guard let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59)) else { return }
        do {
            let txs = try await TransactionService.shared.fetchForPeriod(
                householdId: hid,
                from: yearStart,
                to: yearEnd,
                limit: 50_000
            )
            monthly = (1...12).map { m in
                let monthTxs = txs.filter { cal.component(.month, from: $0.date) == m }
                let ing = monthTxs.filter { $0.type == .ingreso }.reduce(Decimal(0)) { $0 + $1.amount }
                let gas = monthTxs.filter { $0.type == .gasto }.reduce(Decimal(0)) { $0 + $1.amount }
                return MonthTotals(id: m, month: m, ingresos: ing, gastos: gas)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func monthLabel(_ month: Int) -> String {
        let df = DateFormatter()
        df.locale = AppLocaleStorage.effectiveLocale
        df.dateFormat = "MMM"
        let cal = Calendar.current
        guard let date = cal.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return String(month)
        }
        return df.string(from: date).capitalized
    }
}
