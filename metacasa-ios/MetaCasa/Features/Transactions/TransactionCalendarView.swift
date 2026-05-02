import SwiftUI

/// Vista calendario con heatmap de intensidad de gastos por día.
///
/// Paridad con el "spendingCalendar" del web (App.jsx:11057). Implementación
/// iOS-native con:
/// - `LazyVGrid` con 7 columnas (días de la semana)
/// - Color de fondo proporcional al gasto del día (rojo oscuro → claro)
/// - Tap en un día → lista de transacciones de ese día en sheet con
///   `.presentationDetents`
/// - Navegación mes a mes con swipe horizontal (paginación)
struct TransactionCalendarView: View {
    let transactions: [Transaction]
    let currency: String
    let onTap: (Date, [Transaction]) -> Void

    @State private var displayMonth: Date = Date()

    private let weekdaySymbols: [String] = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Lunes
        let df = DateFormatter()
        df.locale = .autoupdatingCurrent
        let symbols = df.veryShortWeekdaySymbols ?? ["D","L","M","M","J","V","S"]
        // Rotar para que empiece en Lunes
        return Array(symbols[1...] + symbols[..<1])
    }()

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            calendarGrid
            legend
        }
        .padding(.horizontal, 16)
        .gesture(DragGesture()
            .onEnded { value in
                if value.translation.width < -50 {
                    withAnimation(.spring) {
                        displayMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                    }
                } else if value.translation.width > 50 {
                    withAnimation(.spring) {
                        displayMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                    }
                }
            }
        )
    }

    // MARK: - Subviews

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.spring) {
                    displayMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(.title3.weight(.bold))

            Spacer()

            Button {
                withAnimation(.spring) {
                    displayMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(weekdaySymbols, id: \.self) { s in
                Text(s.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let days = monthDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days.indices, id: \.self) { i in
                if let date = days[i] {
                    dayCell(date: date)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(date: Date) -> some View {
        let daysTxs = transactionsFor(date: date)
        let totalSpent = daysTxs.filter { $0.type == .gasto }.reduce(Decimal(0)) { $0 + $1.amount }
        let isToday = Calendar.current.isDateInToday(date)
        let intensity = heatmapIntensity(for: totalSpent)

        return Button {
            onTap(date, daysTxs)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(heatmapColor(intensity: intensity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isToday ? Color.brandPrimary : Color.clear, lineWidth: 2)
                    )
                VStack(spacing: 2) {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.callout.weight(isToday ? .bold : .medium))
                        .foregroundStyle(intensity > 0.5 ? Color.white : Color.primary)
                    if totalSpent > 0 {
                        Text(Money.format(totalSpent, currency: currency, style: .abbreviated))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(intensity > 0.5 ? Color.white.opacity(0.9) : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(2)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("cal.legend.less")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(heatmapColor(intensity: Double(i) / 4.0))
                    .frame(width: 16, height: 12)
            }
            Text("cal.legend.more")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Computations

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "LLLL yyyy"
        return f.string(from: displayMonth).capitalized
    }

    /// Devuelve los días del mes con padding al inicio para alinear al weekday.
    /// `nil` indica celda vacía (días de otros meses).
    private func monthDays() -> [Date?] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Lunes
        let comps = cal.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }
        let daysInMonth = range.count
        // Weekday del primer día (1=Domingo). Con firstWeekday=2, padding = (weekday - 2 + 7) % 7
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let padding = (firstWeekday - cal.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: padding)
        for day in 1...daysInMonth {
            var c = comps; c.day = day
            result.append(cal.date(from: c))
        }
        return result
    }

    private func transactionsFor(date: Date) -> [Transaction] {
        let cal = Calendar.current
        return transactions.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    private var maxDailySpent: Decimal {
        var dict: [Date: Decimal] = [:]
        let cal = Calendar.current
        for tx in transactions where tx.type == .gasto {
            let day = cal.startOfDay(for: tx.date)
            dict[day, default: 0] += tx.amount
        }
        return dict.values.max() ?? 1
    }

    private func heatmapIntensity(for amount: Decimal) -> Double {
        guard maxDailySpent > 0 else { return 0 }
        let a = (amount as NSDecimalNumber).doubleValue
        let m = (maxDailySpent as NSDecimalNumber).doubleValue
        return min(1, a / m)
    }

    private func heatmapColor(intensity: Double) -> Color {
        if intensity <= 0 {
            return Color(.tertiarySystemFill)
        }
        // Rojo gradiente. Mezclamos con el fondo system para mantener dark-mode compat.
        return Color.brandDanger.opacity(0.15 + 0.70 * intensity)
    }
}
