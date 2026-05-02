import SwiftUI
import Charts

/// Calculadora de interés compuesto con aportes periódicos — patrón típico
/// de planificación de ahorro: "Si deposito X hoy y le sumo Y cada mes
/// durante N años a una tasa anual Z, ¿cuánto tengo al final?".
///
/// Fórmula aplicada por mes:
///   capital[t+1] = capital[t] * (1 + r/12) + contribution
/// donde r es la TEA expresada en decimal. Se itera mes a mes para captar
/// la composición mensual.
///
/// UX:
/// - Inputs: capital inicial, aporte mensual, años, TEA %.
/// - Outputs: total final, total aportado (capital + aportes), interés ganado.
/// - Chart de línea mostrando evolución del capital vs aportado total.
/// - Moneda: auto-default a la moneda del hogar activo.
struct CompoundInterestCalculatorView: View {
    @Environment(AppState.self) private var appState

    // Inputs como String para bind a TextField con keyboard decimal.
    @State private var principalStr: String = "10000"
    @State private var monthlyStr: String = "500"
    @State private var yearsStr: String = "10"
    @State private var annualRateStr: String = "8"

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    // MARK: - Computed inputs

    private var principal: Decimal { Money.parse(principalStr) ?? 0 }
    private var monthlyContribution: Decimal { Money.parse(monthlyStr) ?? 0 }
    private var years: Int { Int(yearsStr) ?? 0 }
    private var annualRatePct: Double { Double(annualRateStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var months: Int { years * 12 }
    private var monthlyRate: Double { annualRatePct / 100 / 12 }

    // MARK: - Computed outputs

    /// Serie mensual [mes: balance] tras aplicar interés compuesto + aporte.
    private var projection: [MonthlyPoint] {
        guard months > 0 else { return [MonthlyPoint(month: 0, balance: principal, contributed: principal)] }
        var points: [MonthlyPoint] = []
        var balance = (principal as NSDecimalNumber).doubleValue
        var contributed = (principal as NSDecimalNumber).doubleValue
        points.append(MonthlyPoint(month: 0, balance: Decimal(balance), contributed: Decimal(contributed)))

        let m = (monthlyContribution as NSDecimalNumber).doubleValue
        for month in 1...months {
            balance = balance * (1 + monthlyRate) + m
            contributed += m
            points.append(MonthlyPoint(
                month: month,
                balance: Decimal(balance),
                contributed: Decimal(contributed)
            ))
        }
        return points
    }

    private var finalBalance: Decimal {
        projection.last?.balance ?? 0
    }

    private var totalContributed: Decimal {
        projection.last?.contributed ?? principal
    }

    private var interestEarned: Decimal {
        finalBalance - totalContributed
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introCard
                    inputsCard
                    if months > 0 && annualRatePct > 0 {
                        resultsCard
                        chartCard
                        tableCard
                    } else {
                        Text("compound.enterInputs")
                            .font(.mcCaption)
                            .foregroundStyle(Color.textMuted)
                            .padding()
                    }
                    disclaimerCard
                }
                .padding(20)
            }
        }
        .navigationTitle(Text("more.compoundInterest"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Intro

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Color.brandPrimary)
                Text("compound.title").font(.mcH2).foregroundStyle(Color.textPrimary)
            }
            Text("compound.intro")
                .font(.mcCaption)
                .foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    // MARK: - Inputs

    private var inputsCard: some View {
        VStack(spacing: 14) {
            inputRow(
                label: "compound.input.principal",
                hint: "compound.input.principal.hint",
                text: $principalStr,
                keyboard: .decimalPad,
                suffix: currency
            )
            inputRow(
                label: "compound.input.monthly",
                hint: "compound.input.monthly.hint",
                text: $monthlyStr,
                keyboard: .decimalPad,
                suffix: currency
            )
            inputRow(
                label: "compound.input.years",
                hint: "compound.input.years.hint",
                text: $yearsStr,
                keyboard: .numberPad,
                suffix: String(localized: "compound.unit.years")
            )
            inputRow(
                label: "compound.input.rate",
                hint: "compound.input.rate.hint",
                text: $annualRateStr,
                keyboard: .decimalPad,
                suffix: "% TEA"
            )
        }
        .mcCard()
    }

    private func inputRow(
        label: LocalizedStringKey,
        hint: LocalizedStringKey,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        suffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.mcLabel).foregroundStyle(Color.textMuted)
            HStack {
                TextField("", text: text)
                    .keyboardType(keyboard)
                    .font(.mcSerifInline)
                    .monospacedDigit()
                Text(suffix)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(10)
            .background(Color.appSurfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(hint).font(.caption2).foregroundStyle(Color.textDim)
        }
    }

    // MARK: - Results

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("compound.result").font(.mcH2).foregroundStyle(Color.textPrimary)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("compound.result.final").font(.mcLabel).foregroundStyle(Color.textMuted)
                    Text(Money.format(finalBalance, currency: currency, style: .auto))
                        .font(.mcSerifDisplay)
                        .foregroundStyle(Color.brandSuccess)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.brandSuccess)
            }
            Divider().overlay(Color.appBorder)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("compound.result.contributed").font(.mcLabel).foregroundStyle(Color.textMuted)
                    Text(Money.format(totalContributed, currency: currency, style: .auto))
                        .font(.mcSerifAmount)
                        .monospacedDigit()
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("compound.result.interest").font(.mcLabel).foregroundStyle(Color.textMuted)
                    Text(Money.format(interestEarned, currency: currency, style: .auto))
                        .font(.mcSerifAmount)
                        .monospacedDigit()
                        .foregroundStyle(Color.brandPrimary)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.brandSuccess.opacity(0.12), Color.brandPrimary.opacity(0.08), Color.appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("compound.chart.title").font(.mcH2).foregroundStyle(Color.textPrimary)
            Chart {
                ForEach(projection) { p in
                    AreaMark(
                        x: .value("Month", p.month),
                        y: .value("Balance", (p.balance as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandPrimary.opacity(0.4), Color.brandPrimary.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                ForEach(projection) { p in
                    LineMark(
                        x: .value("Month", p.month),
                        y: .value("Balance", (p.balance as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(Color.brandPrimary)
                    .lineStyle(.init(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                ForEach(projection) { p in
                    LineMark(
                        x: .value("Month", p.month),
                        y: .value("Contributed", (p.contributed as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(Color.textMuted.opacity(0.7))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
                }
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: stride(from: 0, through: months, by: max(1, months / 6)).map { $0 })
            }
            HStack(spacing: 14) {
                legendDot(color: Color.brandPrimary, label: "compound.legend.balance")
                legendDot(color: Color.textMuted, label: "compound.legend.contributed")
            }
            .font(.caption2)
        }
        .mcCard()
    }

    private func legendDot(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(Color.textMuted)
        }
    }

    // MARK: - Table

    private var tableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("compound.milestones").font(.mcH2).foregroundStyle(Color.textPrimary)
            ForEach(milestonePoints, id: \.month) { p in
                HStack {
                    Text(milestoneLabel(for: p.month))
                        .font(.mcLabel)
                        .foregroundStyle(Color.textMuted)
                    Spacer()
                    Text(Money.format(p.balance, currency: currency, style: .compact))
                        .font(.mcSerifInline.monospacedDigit())
                        .foregroundStyle(Color.textPrimary)
                }
                if p.month != milestonePoints.last?.month {
                    Divider().overlay(Color.appBorder.opacity(0.3))
                }
            }
        }
        .mcCard()
    }

    /// Snapshot a años redondos (año 1, 5, 10, 20) o a mitades si es <5 años.
    private var milestonePoints: [MonthlyPoint] {
        let yearMarks: [Int]
        if years >= 20 { yearMarks = [1, 5, 10, 15, 20, years] }
        else if years >= 10 { yearMarks = [1, 5, 10, years] }
        else if years >= 5 { yearMarks = [1, 3, 5, years] }
        else if years >= 2 { yearMarks = [1, years] }
        else { yearMarks = [years] }
        var seen: Set<Int> = []
        return yearMarks
            .filter { seen.insert($0).inserted }
            .compactMap { y -> MonthlyPoint? in
                let idx = y * 12
                return projection.first(where: { $0.month == idx })
            }
    }

    private func milestoneLabel(for month: Int) -> LocalizedStringKey {
        let yrs = month / 12
        return LocalizedStringKey("compound.year \(yrs)")
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.textMuted)
                .font(.caption)
            Text("compound.disclaimer")
                .font(.caption2)
                .foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.appSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Model

private struct MonthlyPoint: Identifiable {
    let month: Int
    let balance: Decimal
    let contributed: Decimal
    var id: Int { month }
}
