import WidgetKit
import SwiftUI

/// Widget Home/Lock Screen que muestra el balance del mes + próximo
/// vencimiento. Lee del App Group (`group.com.metacasa.shared`).
///
/// **Este archivo es template — NO está incluido en la target actual**.
/// Para activarlo:
/// 1. Seguir los pasos en `WidgetSnapshot.swift` (App Group setup).
/// 2. Agregar target `MetaCasaWidgets` en `project.yml`:
///    ```yaml
///    targets:
///      MetaCasaWidgets:
///        type: app-extension
///        platform: iOS
///        deploymentTarget: "17.0"
///        sources:
///          - path: MetaCasaWidgets
///        settings:
///          base:
///            PRODUCT_BUNDLE_IDENTIFIER: com.metacasa.app.widgets
///            INFOPLIST_FILE: MetaCasaWidgets/Info.plist
///            CODE_SIGN_ENTITLEMENTS: MetaCasaWidgets/MetaCasaWidgets.entitlements
///    ```
/// 3. Agregar `MetaCasaWidgets` como dependency embed en el target principal.
/// 4. `xcodegen generate` y rebuild.
/// 5. La app principal debe llamar `WidgetSnapshotSync.writeLatest()` al
///    actualizar datos — handler incluido en `Core/WidgetSnapshotSync.swift`.

struct BalanceWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct BalanceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceWidgetEntry {
        BalanceWidgetEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceWidgetEntry) -> Void) {
        completion(BalanceWidgetEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceWidgetEntry>) -> Void) {
        let now = Date()
        let entry = BalanceWidgetEntry(date: now, snapshot: WidgetSnapshot.load())
        // Refresh cada 30 minutos — la app reescribe el snapshot en background
        // via `WidgetSnapshotSync` al cambiar datos relevantes.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot: snapshot)
        } else {
            placeholderView
        }
    }

    @ViewBuilder
    private func content(snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .systemSmall:
            smallLayout(snapshot: snapshot)
        case .systemMedium:
            mediumLayout(snapshot: snapshot)
        case .accessoryRectangular:
            rectangularLayout(snapshot: snapshot)
        case .accessoryInline:
            Text(snapshot.balanceMonth)
        case .accessoryCircular:
            Text(snapshot.balanceMonth).font(.caption2.bold())
        default:
            mediumLayout(snapshot: snapshot)
        }
    }

    private func smallLayout(snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Balance").font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(snapshot.balanceMonth)
                .font(.title3.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer()
            Text(snapshot.householdName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
    }

    private func mediumLayout(snapshot: WidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Balance").font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(snapshot.balanceMonth)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label(snapshot.ingresosMonth, systemImage: "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Label(snapshot.gastosMonth, systemImage: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            if let title = snapshot.nextBillTitle,
               let amount = snapshot.nextBillAmount {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Próximo").font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                    Text(title)
                        .font(.caption2)
                        .lineLimit(1)
                    Text(amount)
                        .font(.caption.bold().monospacedDigit())
                    if let days = snapshot.nextBillInDays {
                        Text(days <= 0 ? "Hoy" : "En \(days)d")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
    }

    private func rectangularLayout(snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Balance").font(.caption2.weight(.bold))
            Text(snapshot.balanceMonth).font(.headline).monospacedDigit()
        }
    }

    private var placeholderView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("app.name").font(.caption.weight(.bold))
            Text("Abrí la app para ver tu balance").font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

struct BalanceWidget: Widget {
    let kind: String = "BalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceWidgetProvider()) { entry in
            BalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Balance del mes")
        .description("Tu balance, ingresos, gastos y próximo vencimiento.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct MetaCasaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
    }
}
