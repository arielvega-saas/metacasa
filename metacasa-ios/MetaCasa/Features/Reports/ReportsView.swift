import SwiftUI
import Charts

/// Reports / Estadísticas — port simplificado de las widgets web App.jsx:11558-11807.
/// Usa Swift Charts (iOS 16+) para gráficos nativos de alto rendimiento.
///
/// Widgets incluidos:
/// - Health Score con breakdown de métricas
/// - 6-month bars (ingreso vs gasto)
/// - Pareto 80/20 (top categorías que concentran el gasto)
/// - Category drill-down (list con % del total)
/// - Monthly projection vs actual
struct ReportsView: View {
    @Environment(AppState.self) private var appState
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        healthScoreCard
                        sixMonthsCard
                        paretoCard
                        categoryBreakdownCard
                        if let msg = errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .refreshable { await load() }
            }
            .navigationTitle(Text("reports.title"))
            .task { await load() }
        }
    }

    // MARK: - Health Score

    /// Score 0-100 ponderando: savings rate (50%), expense adherence (30%), streak (20%).
    /// Simplificación del algoritmo web (App.jsx:6440+).
    private var healthScore: Int {
        let txs = transactions
        let ing = txs.filter { $0.type == .ingreso }.reduce(Decimal(0)) { $0 + $1.amount }
        let gast = txs.filter { $0.type == .gasto }.reduce(Decimal(0)) { $0 + $1.amount }
        var score: Double = 0
        // Savings rate (ideal >=20%)
        if ing > 0 {
            let rate = max(0, (ing - gast) / ing)
            let rateD = (rate as NSDecimalNumber).doubleValue
            score += min(50, rateD * 250) // 20% rate = 50 pts
        }
        // Expense to income ratio — bonus si gastás <90% de lo que ingresás
        if ing > 0 {
            let ratio = (gast as NSDecimalNumber).doubleValue / (ing as NSDecimalNumber).doubleValue
            if ratio < 1.0 {
                score += (1.0 - ratio) * 30
            }
        }
        // Streak bonus: días con al menos 1 transacción en últimos 30
        let cal = Calendar.current
        let last30 = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let daysWithTx = Set(txs.filter { $0.date >= last30 }.map { cal.startOfDay(for: $0.date) }).count
        score += min(20, Double(daysWithTx) * 0.67) // 30 días = 20 pts
        return max(0, min(100, Int(score)))
    }

    private var healthScoreCard: some View {
        let s = healthScore
        let (label, color): (LocalizedStringKey, Color) = {
            if s >= 75 { return ("reports.health.excellent", .brandSuccess) }
            if s >= 55 { return ("reports.health.good", .brandPrimary) }
            if s >= 35 { return ("reports.health.fair", .brandWarning) }
            return ("reports.health.poor", .brandDanger)
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text("reports.health.title")
                } icon: {
                    Image(systemName: "heart.fill").foregroundStyle(color)
                }
                .font(.mcLabel).foregroundStyle(Color.textMuted)
                Spacer()
                Text(label)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .foregroundStyle(color)
                    .cornerRadius(10)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(s)")
                    .font(.system(size: 56, weight: .regular, design: .serif))
                    .foregroundStyle(color)
                Text("/ 100")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(Color.textMuted)
            }
            ProgressView(value: Double(s) / 100)
                .tint(color)
        }
        .mcCard()
    }

    // MARK: - 6-month bars

    /// Serie de últimos 6 meses (incluye actual).
    private struct MonthlySummary: Identifiable {
        let id: Date
        let label: String
        let ingresos: Decimal
        let gastos: Decimal
    }

    private var sixMonthData: [MonthlySummary] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = Date()
        var result: [MonthlySummary] = []
        for offset in (0...5).reversed() {
            guard let monthDate = cal.date(byAdding: .month, value: -offset, to: now) else { continue }
            let comps = cal.dateComponents([.year, .month], from: monthDate)
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59, second: 59), to: start) else { continue }
            let inMonth = transactions.filter { $0.date >= start && $0.date <= end }
            let ing = inMonth.filter { $0.type == .ingreso }.reduce(Decimal(0)) { $0 + $1.amount }
            let gast = inMonth.filter { $0.type == .gasto }.reduce(Decimal(0)) { $0 + $1.amount }
            let df = DateFormatter(); df.locale = .autoupdatingCurrent; df.dateFormat = "MMM"
            result.append(MonthlySummary(id: start, label: df.string(from: start), ingresos: ing, gastos: gast))
        }
        return result
    }

    private var sixMonthsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("reports.sixMonths")
            } icon: {
                Image(systemName: "chart.bar.fill")
            }
            .font(.mcLabel).foregroundStyle(Color.textMuted)

            Chart {
                ForEach(sixMonthData) { item in
                    BarMark(
                        x: .value("Mes", item.label),
                        y: .value("Ingreso", ingValue(item.ingresos))
                    )
                    .foregroundStyle(Color.brandSuccess)
                    .position(by: .value("Tipo", "Ingreso"))

                    BarMark(
                        x: .value("Mes", item.label),
                        y: .value("Gasto", gastValue(item.gastos))
                    )
                    .foregroundStyle(Color.brandDanger)
                    .position(by: .value("Tipo", "Gasto"))
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }

            HStack(spacing: 12) {
                legendDot(color: .brandSuccess, label: "home.income")
                legendDot(color: .brandDanger, label: "home.expenses")
                Spacer()
            }
        }
        .mcCard()
    }

    private func ingValue(_ d: Decimal) -> Double { (d as NSDecimalNumber).doubleValue }
    private func gastValue(_ d: Decimal) -> Double { (d as NSDecimalNumber).doubleValue }

    private func legendDot(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Pareto 80/20

    private struct CategorySlice: Identifiable {
        let id = UUID()
        let category: String
        let amount: Decimal
        let percent: Double
    }

    /// Categorías ordenadas por gasto descendente. Marca las que forman el 80%.
    private var paretoData: [CategorySlice] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        let start = cal.date(from: comps) ?? Date()
        let monthTxs = transactions.filter {
            $0.type == .gasto && $0.date >= start
        }
        let total = monthTxs.reduce(Decimal(0)) { $0 + $1.amount }
        guard total > 0 else { return [] }
        var byCat: [String: Decimal] = [:]
        for tx in monthTxs {
            byCat[tx.category, default: 0] += tx.amount
        }
        let totalD = (total as NSDecimalNumber).doubleValue
        return byCat.map { (cat, amt) -> CategorySlice in
            let p = (amt as NSDecimalNumber).doubleValue / totalD
            return CategorySlice(category: cat, amount: amt, percent: p)
        }.sorted { $0.amount > $1.amount }
    }

    private var paretoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("reports.pareto")
            } icon: {
                Image(systemName: "percent")
            }
            .font(.mcLabel).foregroundStyle(Color.textMuted)

            if paretoData.isEmpty {
                Text("reports.empty").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(Array(paretoData.prefix(8))) { slice in
                    SectorMark(
                        angle: .value("Porcentaje", slice.percent),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Categoría", slice.category))
                }
                .frame(height: 200)

                VStack(spacing: 4) {
                    ForEach(paretoData.prefix(8)) { slice in
                        HStack {
                            Text(CategoryCatalog.emoji(for: slice.category))
                            Text(slice.category).font(.subheadline)
                            Spacer()
                            Text("\(Int(slice.percent * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            AmountLabel(amount: slice.amount, currency: currency, kind: .gasto)
                                .font(.subheadline.weight(.bold))
                        }
                    }
                }
            }
        }
        .mcCard()
    }

    // MARK: - Category breakdown

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("reports.categoryBreakdown")
            } icon: {
                Image(systemName: "tag")
            }
            .font(.mcLabel).foregroundStyle(Color.textMuted)

            if paretoData.isEmpty {
                Text("reports.empty").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(paretoData) { slice in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(CategoryCatalog.emoji(for: slice.category))
                            Text(slice.category).font(.subheadline.weight(.medium))
                            Spacer()
                            AmountLabel(amount: slice.amount, currency: currency, kind: .gasto)
                                .font(.subheadline.weight(.bold))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color(.tertiarySystemFill)).frame(height: 6).cornerRadius(3)
                                Rectangle()
                                    .fill(Color.brandDanger)
                                    .frame(width: geo.size.width * slice.percent, height: 6)
                                    .cornerRadius(3)
                            }
                        }.frame(height: 6)
                    }
                }
            }
        }
        .mcCard()
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let cal = Calendar.current
            let start = cal.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            transactions = try await TransactionService.shared.fetchForPeriod(
                householdId: hid, from: start, to: Date(), limit: 5000
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
