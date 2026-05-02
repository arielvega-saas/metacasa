import Foundation
import SwiftUI
import Observation

/// Preferencias del Dashboard (Home). El usuario puede:
/// - Ocultar widgets que no le interesan (`hiddenWidgets` Set).
/// - Reordenar los widgets arrastrándolos en el editor (`order` array).
///
/// Ambas preferencias persisten en UserDefaults. Si el orden persistido
/// está desactualizado (salió un widget nuevo en un update), se reconcilia
/// en `init` agregando los faltantes al final.
@MainActor
@Observable
final class DashboardPreferences {
    static let shared = DashboardPreferences()

    var hiddenWidgets: Set<DashboardWidgetID>
    /// Orden visual de los widgets en el Home. Por default sigue el orden de
    /// `DashboardWidgetID.allCases`. Se persiste como array de rawValues.
    var order: [DashboardWidgetID]

    private init() {
        let raw = UserDefaults.standard.stringArray(forKey: "dashboard_hidden") ?? []
        self.hiddenWidgets = Set(raw.compactMap(DashboardWidgetID.init(rawValue:)))

        let persistedOrder = UserDefaults.standard.stringArray(forKey: "dashboard_order") ?? []
        let restored = persistedOrder.compactMap(DashboardWidgetID.init(rawValue:))
        let defaults = DashboardWidgetID.allCases
        // Reconciliación: conservar orden del user + agregar cases nuevos al final.
        let known = Set(restored)
        let missing = defaults.filter { !known.contains($0) }
        self.order = restored + missing
    }

    func toggle(_ widget: DashboardWidgetID) {
        if hiddenWidgets.contains(widget) {
            hiddenWidgets.remove(widget)
        } else {
            hiddenWidgets.insert(widget)
        }
        persistHidden()
    }

    func isVisible(_ widget: DashboardWidgetID) -> Bool {
        !hiddenWidgets.contains(widget)
    }

    /// Lista ordenada de widgets visibles, en el orden que definió el user.
    /// HomeView itera acá para renderizar el dashboard.
    var orderedVisibleWidgets: [DashboardWidgetID] {
        order.filter { !hiddenWidgets.contains($0) }
    }

    /// Mueve widgets dentro del array `order`. Se usa desde `.onMove` del
    /// `List` del DashboardEditorSheet.
    func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        persistOrder()
    }

    func resetToDefaults() {
        hiddenWidgets.removeAll()
        order = DashboardWidgetID.allCases
        persistHidden()
        persistOrder()
    }

    private func persistHidden() {
        UserDefaults.standard.set(
            hiddenWidgets.map(\.rawValue).sorted(),
            forKey: "dashboard_hidden"
        )
    }

    private func persistOrder() {
        UserDefaults.standard.set(
            order.map(\.rawValue),
            forKey: "dashboard_order"
        )
    }
}

/// IDs canónicos de cada widget del Home. `rawValue` se persiste en UserDefaults.
enum DashboardWidgetID: String, CaseIterable, Sendable, Identifiable {
    case hero
    case stats
    case insight
    case health
    case netWorth
    case savingsInvestment
    case readyToAssign
    case upcomingBills
    case goals
    case categories
    case shortcuts
    case debts

    var id: String { rawValue }

    var labelKey: LocalizedStringKey {
        switch self {
        case .hero:              return "dashboard.widget.hero"
        case .stats:             return "dashboard.widget.stats"
        case .insight:           return "dashboard.widget.insight"
        case .health:            return "dashboard.widget.health"
        case .netWorth:          return "dashboard.widget.netWorth"
        case .savingsInvestment: return "dashboard.widget.savingsInvestment"
        case .readyToAssign:     return "dashboard.widget.readyToAssign"
        case .upcomingBills:     return "dashboard.widget.bills"
        case .goals:             return "dashboard.widget.goals"
        case .categories:        return "dashboard.widget.categories"
        case .shortcuts:         return "dashboard.widget.shortcuts"
        case .debts:             return "dashboard.widget.debts"
        }
    }

    var icon: String {
        switch self {
        case .hero:              return "creditcard.fill"
        case .stats:             return "chart.line.uptrend.xyaxis"
        case .insight:           return "sparkles"
        case .health:            return "heart.fill"
        case .netWorth:          return "scale.3d"
        case .savingsInvestment: return "banknote.fill"
        case .readyToAssign:     return "checkmark.seal.fill"
        case .upcomingBills:     return "calendar.badge.exclamationmark"
        case .goals:             return "target"
        case .categories:        return "chart.pie.fill"
        case .shortcuts:         return "bolt.fill"
        case .debts:             return "arrow.down.to.line"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .hero:              return "dashboard.widget.hero.desc"
        case .stats:             return "dashboard.widget.stats.desc"
        case .insight:           return "dashboard.widget.insight.desc"
        case .health:            return "dashboard.widget.health.desc"
        case .netWorth:          return "dashboard.widget.netWorth.desc"
        case .savingsInvestment: return "dashboard.widget.savingsInvestment.desc"
        case .readyToAssign:     return "dashboard.widget.readyToAssign.desc"
        case .upcomingBills:     return "dashboard.widget.bills.desc"
        case .goals:             return "dashboard.widget.goals.desc"
        case .categories:        return "dashboard.widget.categories.desc"
        case .shortcuts:         return "dashboard.widget.shortcuts.desc"
        case .debts:             return "dashboard.widget.debts.desc"
        }
    }
}
