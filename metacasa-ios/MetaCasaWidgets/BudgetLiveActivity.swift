import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity que muestra el estado de "Presupuesto del mes" en el
/// Dynamic Island + Lock Screen mientras el usuario está activamente cargando
/// gastos durante el día.
///
/// **Este archivo es template — para activarlo**:
/// 1. Asegurarte de que el target `MetaCasaWidgets` existe (ver BalanceWidget.swift).
/// 2. Agregar `NSSupportsLiveActivities = true` al `Info.plist` de la app
///    principal (`MetaCasa/Supporting/Info.plist`).
/// 3. Iniciar desde la app cuando corresponda:
///    ```swift
///    let attributes = BudgetActivityAttributes(
///        periodStart: start, periodEnd: end, currency: currency
///    )
///    let state = BudgetActivityAttributes.ContentState(
///        balance: balance, allocated: allocated, spent: spent
///    )
///    let activity = try Activity.request(
///        attributes: attributes,
///        content: .init(state: state, staleDate: nil)
///    )
///    ```
/// 4. Actualizar vía `activity.update(using: newState)`.

struct BudgetActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Balance actual del mes (ingresos - gastos).
        public let balance: Decimal
        /// Total asignado en envelopes.
        public let allocated: Decimal
        /// Total gastado en el período.
        public let spent: Decimal
    }

    /// Start + end del período del presupuesto.
    public let periodStart: Date
    public let periodEnd: Date
    public let currency: String
}

struct BudgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            // Lock screen / banner UI
            lockScreenView(for: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("Balance").font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(formatAmount(context.state.balance, currency: context.attributes.currency))
                            .font(.title3.bold())
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Gastado").font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(formatAmount(context.state.spent, currency: context.attributes.currency))
                            .font(.callout.bold())
                            .monospacedDigit()
                            .foregroundStyle(.red)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    progressBar(context: context)
                }
            } compactLeading: {
                Image(systemName: "chart.pie.fill")
            } compactTrailing: {
                Text(formatAmount(context.state.balance, currency: context.attributes.currency))
                    .font(.caption2.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } minimal: {
                Image(systemName: "chart.pie.fill")
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(for context: ActivityViewContext<BudgetActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Presupuesto del mes", systemImage: "chart.pie.fill")
                    .font(.caption.weight(.bold))
                Spacer()
                Text(context.attributes.periodEnd, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                amountTile(label: "Balance", amount: context.state.balance, currency: context.attributes.currency, positive: true)
                amountTile(label: "Gastado", amount: context.state.spent, currency: context.attributes.currency, positive: false)
            }

            progressBar(context: context)
        }
        .padding()
    }

    private func amountTile(label: String, amount: Decimal, currency: String, positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(formatAmount(amount, currency: currency))
                .font(.callout.bold())
                .monospacedDigit()
                .foregroundStyle(positive && amount >= 0 ? .primary : (amount < 0 ? .red : .primary))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func progressBar(context: ActivityViewContext<BudgetActivityAttributes>) -> some View {
        let allocated = (context.state.allocated as NSDecimalNumber).doubleValue
        let spent = (context.state.spent as NSDecimalNumber).doubleValue
        let pct = allocated > 0 ? min(1, spent / allocated) : 0

        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pct > 0.9 ? Color.red : (pct > 0.7 ? Color.orange : Color.green))
                        .frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(Int(pct * 100))% usado")
                    .font(.caption2)
                Spacer()
                Text(formatAmount(context.state.allocated, currency: context.attributes.currency))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
