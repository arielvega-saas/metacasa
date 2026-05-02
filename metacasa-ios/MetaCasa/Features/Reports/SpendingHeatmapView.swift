import SwiftUI

/// Heatmap anual estilo GitHub contribution graph: grilla de 7×52 semanas
/// donde cada celda representa un día del año y la intensidad del color
/// muestra cuánto gastaste ese día.
///
/// UX:
/// - Eje Y = día de la semana (Dom-Sáb).
/// - Eje X = semanas del año, scrollable horizontal.
/// - Colores: 5 niveles (0, bajo, medio, alto, muy alto) basados en quintiles
///   del gasto diario del user (no thresholds fijos — se adapta al volumen).
/// - Tap en una celda → muestra un popover con la fecha + monto exacto.
/// - Toggle año (actual vs anteriores) en el header.
///
/// Paridad con patrones de apps financieras (Copilot, Cleo) que incluyen
/// heatmaps para detectar rápido días atípicos.
struct SpendingHeatmapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var dailyTotals: [Date: Decimal] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDay: DayCell?

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        yearPicker
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        } else {
                            statsHeader
                            heatmapGrid
                            legend
                            if let sel = selectedDay {
                                selectedCard(sel)
                            }
                        }
                        if let msg = errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(Color.brandDanger)
                        }
                        Text("heatmap.hint")
                            .font(.mcCaption)
                            .foregroundStyle(Color.textMuted)
                            .padding(.top, 12)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(Text("heatmap.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                }
            }
            .task { await load() }
            .task(id: year) { await load() }
        }
    }

    // MARK: - Header

    private var yearPicker: some View {
        HStack {
            Button {
                Haptics.play(.selection)
                year -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Text(String(year))
                .font(.mcSerifTitle)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button {
                let maxYear = Calendar.current.component(.year, from: Date())
                if year < maxYear {
                    Haptics.play(.selection)
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

    private var statsHeader: some View {
        let total = dailyTotals.values.reduce(Decimal(0), +)
        let activeDays = dailyTotals.filter { $0.value > 0 }.count
        let avg = activeDays > 0 ? total / Decimal(activeDays) : 0
        return HStack(spacing: 12) {
            stat(label: "heatmap.stats.total", value: Money.format(total, currency: currency, style: .compact))
            stat(label: "heatmap.stats.activeDays", value: "\(activeDays)")
            stat(label: "heatmap.stats.avgPerDay", value: Money.format(avg, currency: currency, style: .compact))
        }
    }

    private func stat(label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.mcLabel).foregroundStyle(Color.textMuted)
            Text(value).font(.mcSerifInline).foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    // MARK: - Grid

    /// Grilla 7×N: filas son días de la semana (Dom=0 ... Sáb=6), columnas
    /// son semanas del año (52 o 53). ScrollView horizontal.
    private var heatmapGrid: some View {
        let allCells = buildCells()
        let quintiles = computeQuintiles(allCells: allCells)
        let weeks = Dictionary(grouping: allCells, by: \.weekOfYear)
            .sorted { $0.key < $1.key }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                // Eje Y: labels de días
                VStack(alignment: .trailing, spacing: 4) {
                    Color.clear.frame(height: 10) // spacer para header meses
                    dayLabel("L")
                    dayLabel(" ")
                    dayLabel("M")
                    dayLabel(" ")
                    dayLabel("V")
                    dayLabel(" ")
                    dayLabel(" ")
                }
                .padding(.trailing, 2)

                ForEach(weeks, id: \.key) { weekNum, days in
                    VStack(alignment: .leading, spacing: 4) {
                        // Label del mes si es la 1ra semana o cambia el mes.
                        monthLabel(for: days)
                            .frame(height: 10)
                        ForEach(0..<7, id: \.self) { weekday in
                            if let cell = days.first(where: { $0.weekday == weekday }) {
                                cellView(cell, quintiles: quintiles)
                            } else {
                                Color.clear.frame(width: 13, height: 13)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .mcCard()
    }

    private func dayLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color.textMuted)
            .frame(width: 12, height: 13)
    }

    private func monthLabel(for days: [DayCell]) -> some View {
        // Solo mostrar el nombre del mes si la semana contiene el día 1-7 del mes.
        let shows = days.first(where: { $0.dayOfMonth <= 7 })
        return Group {
            if let shows {
                Text(monthShortName(for: shows.date))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
            } else {
                Text("")
            }
        }
    }

    private func cellView(_ cell: DayCell, quintiles: Quintiles) -> some View {
        let intensity = quintiles.bucket(for: cell.amount)
        let isSelected = selectedDay?.id == cell.id
        return Button {
            Haptics.play(.selection)
            selectedDay = cell
        } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(colorFor(intensity: intensity))
                .frame(width: 13, height: 13)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(
                            isSelected ? Color.brandPrimary : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func colorFor(intensity: Int) -> Color {
        switch intensity {
        case 0: return Color.appSurfaceInset
        case 1: return Color.brandPrimary.opacity(0.25)
        case 2: return Color.brandPrimary.opacity(0.45)
        case 3: return Color.brandPrimary.opacity(0.7)
        case 4: return Color.brandPrimary
        default: return Color.brandPrimary
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 6) {
            Text("heatmap.legend.less").font(.caption2).foregroundStyle(Color.textMuted)
            ForEach(0...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(colorFor(intensity: i))
                    .frame(width: 12, height: 12)
            }
            Text("heatmap.legend.more").font(.caption2).foregroundStyle(Color.textMuted)
        }
    }

    // MARK: - Selected day card

    private func selectedCard(_ sel: DayCell) -> some View {
        let df = DateFormatter()
        df.locale = AppLocaleStorage.effectiveLocale
        df.setLocalizedDateFormatFromTemplate("EEEE dd MMMM yyyy")
        return VStack(alignment: .leading, spacing: 6) {
            Text(df.string(from: sel.date).capitalized)
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            Text(Money.format(sel.amount, currency: currency, style: .auto))
                .font(.mcSerifAmount)
                .foregroundStyle(sel.amount > 0 ? Color.brandDanger : Color.textMuted)
            if sel.amount == 0 {
                Text("heatmap.selected.noSpend")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Data

    @MainActor
    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        var startComps = DateComponents(); startComps.year = year; startComps.month = 1; startComps.day = 1
        var endComps = DateComponents(); endComps.year = year; endComps.month = 12; endComps.day = 31
        endComps.hour = 23; endComps.minute = 59
        guard let start = cal.date(from: startComps),
              let end = cal.date(from: endComps)
        else { return }

        do {
            let txs = try await TransactionService.shared.fetchForPeriod(
                householdId: hid, from: start, to: end, limit: 20_000
            )
            var totals: [Date: Decimal] = [:]
            for tx in txs where tx.type == .gasto {
                let day = cal.startOfDay(for: tx.date)
                totals[day, default: 0] += tx.amount
            }
            dailyTotals = totals
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Cell building

    private func buildCells() -> [DayCell] {
        let cal = Calendar.current
        var cells: [DayCell] = []
        var startComps = DateComponents(); startComps.year = year; startComps.month = 1; startComps.day = 1
        guard let start = cal.date(from: startComps) else { return [] }
        let daysInYear = cal.range(of: .day, in: .year, for: start)?.count ?? 365

        for offset in 0..<daysInYear {
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = cal.component(.weekday, from: date) - 1 // 0-6 (Dom=0)
            let weekOfYear = cal.component(.weekOfYear, from: date)
            let dayOfMonth = cal.component(.day, from: date)
            let amount = dailyTotals[cal.startOfDay(for: date)] ?? 0
            cells.append(DayCell(
                date: date,
                weekday: weekday,
                weekOfYear: weekOfYear,
                dayOfMonth: dayOfMonth,
                amount: amount
            ))
        }
        return cells
    }

    private func computeQuintiles(allCells: [DayCell]) -> Quintiles {
        let nonZero = allCells.map(\.amount).filter { $0 > 0 }.sorted()
        guard nonZero.count >= 5 else {
            // Data insuficiente — usar thresholds por magnitud heurística.
            let max = nonZero.last ?? 0
            return Quintiles(q1: max / 5, q2: max * 2 / 5, q3: max * 3 / 5, q4: max * 4 / 5)
        }
        let n = nonZero.count
        return Quintiles(
            q1: nonZero[n / 5],
            q2: nonZero[2 * n / 5],
            q3: nonZero[3 * n / 5],
            q4: nonZero[4 * n / 5]
        )
    }

    private func monthShortName(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = AppLocaleStorage.effectiveLocale
        df.setLocalizedDateFormatFromTemplate("MMM")
        return df.string(from: date).uppercased()
    }
}

// MARK: - Models

private struct DayCell: Identifiable, Equatable {
    let date: Date
    let weekday: Int
    let weekOfYear: Int
    let dayOfMonth: Int
    let amount: Decimal

    var id: Date { date }
}

private struct Quintiles {
    let q1: Decimal
    let q2: Decimal
    let q3: Decimal
    let q4: Decimal

    /// Devuelve 0-4: 0 = sin gasto, 1-4 = intensidad creciente.
    func bucket(for amount: Decimal) -> Int {
        if amount <= 0 { return 0 }
        if amount < q1 { return 1 }
        if amount < q2 { return 2 }
        if amount < q3 { return 3 }
        if amount < q4 { return 4 }
        return 4
    }
}
