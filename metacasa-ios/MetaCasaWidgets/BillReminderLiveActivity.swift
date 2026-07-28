import ActivityKit
import SwiftUI
import WidgetKit

/// UI de la Live Activity del próximo vencimiento (Lock Screen + Dynamic
/// Island). El control (start/update/end) vive en la app:
/// `MetaCasa/Core/LiveActivityService.swift`, que dispara sobre los mismos
/// `BillReminderAttributes` compartidos por ambos targets.
@available(iOS 16.2, *)
struct BillReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BillReminderAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vence")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(context.state.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.formattedAmount)
                            .font(.headline.monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(relativeDue(context.state))
                            .font(.caption2)
                            .foregroundStyle(urgencyColor(context.state))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.dueDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(urgencyColor(context.state))
            } compactTrailing: {
                Text(context.state.formattedAmount)
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(urgencyColor(context.state))
            }
        }
    }

    @ViewBuilder
    private func lockScreen(_ state: BillReminderAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(urgencyColor(state))
            VStack(alignment: .leading, spacing: 3) {
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(relativeDue(state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(state.formattedAmount)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// "Vence hoy" / "Vence mañana" / "Vencido" según horas restantes.
    private func relativeDue(_ state: BillReminderAttributes.ContentState) -> String {
        let hours = state.hoursUntilDue
        if hours < 0 { return "Vencido" }
        if hours < 24 { return "Vence hoy" }
        if hours < 48 { return "Vence mañana" }
        return "Vence en \(hours / 24) días"
    }

    private func urgencyColor(_ state: BillReminderAttributes.ContentState) -> Color {
        let hours = state.hoursUntilDue
        if hours < 0 { return .red }
        if hours < 24 { return .orange }
        return .yellow
    }
}
