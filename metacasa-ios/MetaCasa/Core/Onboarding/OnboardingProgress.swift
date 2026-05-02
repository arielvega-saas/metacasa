import Foundation
import SwiftUI
import Observation

/// Checklist de setup inicial para que el usuario sepa qué le falta para
/// aprovechar la app (ver estado real de sus datos, presupuesto, metas).
///
/// Cada step se **auto-detecta** consultando servicios (AccountService,
/// TransactionService, BudgetService, etc.) — NO se guarda como flag del
/// usuario, así que siempre refleja el estado verdadero.
///
/// Cuando todos los steps están completos `isComplete == true`, el widget
/// `SetupChecklistCard` del Home se oculta automáticamente. Si el usuario
/// quiere esconderlo antes de completarlo, puede dismissearlo manualmente
/// (`dismissForever()` — persiste en UserDefaults).
///
/// Uso en HomeView:
/// ```swift
/// @Environment(OnboardingProgress.self) private var onboarding
/// if onboarding.shouldShow {
///     SetupChecklistCard()
/// }
/// ```
@MainActor
@Observable
final class OnboardingProgress {

    // MARK: - State

    /// Lista actual de steps con flag `isDone`. Se regenera en `refresh()`.
    var steps: [SetupStep] = SetupStep.ID.allCases.map { SetupStep(id: $0, isDone: false) }

    /// `true` si el usuario tocó "No volver a mostrar". Persiste en UserDefaults.
    private(set) var isDismissed: Bool

    /// `true` mientras `refresh()` está corriendo. Útil para deshabilitar taps.
    var isRefreshing = false

    private static let dismissedKey = "onboarding_checklist_dismissed"

    init() {
        self.isDismissed = UserDefaults.standard.bool(forKey: Self.dismissedKey)
    }

    // MARK: - Computed

    var progress: Double {
        let total = steps.count
        guard total > 0 else { return 0 }
        let done = steps.filter(\.isDone).count
        return Double(done) / Double(total)
    }

    var doneCount: Int { steps.filter(\.isDone).count }

    var isComplete: Bool { !steps.isEmpty && steps.allSatisfy(\.isDone) }

    /// El card del Home se muestra si (a) no fue dismissed manualmente,
    /// (b) hay hogar activo (si no, el user está pre-onboarding),
    /// (c) no todos los steps están ok.
    var shouldShow: Bool {
        !isDismissed && !isComplete
    }

    // MARK: - Actions

    /// Recomputa el estado de cada step fetcheando los servicios reales.
    /// Se llama cuando el Home aparece o después de acciones que podrían
    /// cambiar el progreso (ej: agregar primera transacción).
    func refresh(appState: AppState) async {
        isRefreshing = true
        defer { isRefreshing = false }

        guard let hid = appState.currentHouseholdId else {
            // Sin hogar → solo el primer step puede estar done (y no lo está
            // si no hay hid). Dejamos todo en false.
            steps = SetupStep.ID.allCases.map { SetupStep(id: $0, isDone: false) }
            return
        }

        // Paralelizamos todos los fetches para minimizar latencia.
        async let accountsTask = AccountService.shared.fetchAll(householdId: hid, includingInactive: true)
        async let goalsTask    = GoalService.shared.fetchAll(householdId: hid, includeCompleted: false)
        async let billsTask    = BillService.shared.fetchAll(householdId: hid, includeCompleted: false)

        // Transacciones: traemos las últimas del mes actual (y mes anterior para fallback).
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -60, to: now) ?? now
        async let txsTask = TransactionService.shared.fetchForPeriod(
            householdId: hid, from: start, to: now, limit: 1
        )

        // Budget: el step "firstBudget" se marca done SOLO si hay al menos 1
        // allocation — no solo periodo creado automáticamente al visitar el tab.
        async let budgetTask = BudgetService.shared.fetchPeriod(householdId: hid, containing: now)

        let accounts = (try? await accountsTask) ?? []
        let goals    = (try? await goalsTask) ?? []
        let bills    = (try? await billsTask) ?? []
        let txs      = (try? await txsTask) ?? []
        let period   = try? await budgetTask

        // Para budget: chequeamos si hay allocations en el period actual.
        let hasBudgetAllocations: Bool = await {
            guard let p = period else { return false }
            let allocs = (try? await BudgetService.shared.fetchAllocations(periodId: p.id)) ?? []
            return !allocs.isEmpty
        }()

        // Notification permission
        let notifState = await NotificationService.shared.authorizationState()
        let notifGranted = notifState == .authorized

        // Compose steps
        var out: [SetupStep] = []
        out.append(.init(id: .createHousehold, isDone: true))  // siempre done si hay hid
        out.append(.init(id: .firstAccount,     isDone: !accounts.isEmpty))
        out.append(.init(id: .firstTransaction, isDone: !txs.isEmpty))
        out.append(.init(id: .firstBudget,      isDone: hasBudgetAllocations))
        out.append(.init(id: .firstGoalOrBill,  isDone: !goals.isEmpty || !bills.isEmpty))
        out.append(.init(id: .notifications,    isDone: notifGranted))
        steps = out
    }

    /// El usuario optó por no ver más el card. Persiste.
    func dismissForever() {
        isDismissed = true
        UserDefaults.standard.set(true, forKey: Self.dismissedKey)
    }

    /// Testing / reset desde Ajustes > Debug.
    func resetDismissal() {
        isDismissed = false
        UserDefaults.standard.removeObject(forKey: Self.dismissedKey)
    }
}

// MARK: - SetupStep

struct SetupStep: Identifiable, Equatable {
    let id: ID
    var isDone: Bool

    enum ID: String, CaseIterable {
        case createHousehold
        case firstAccount
        case firstTransaction
        case firstBudget
        case firstGoalOrBill
        case notifications

        var titleKey: LocalizedStringKey {
            switch self {
            case .createHousehold:  return "onboarding.step.household.title"
            case .firstAccount:     return "onboarding.step.account.title"
            case .firstTransaction: return "onboarding.step.transaction.title"
            case .firstBudget:      return "onboarding.step.budget.title"
            case .firstGoalOrBill:  return "onboarding.step.goalOrBill.title"
            case .notifications:    return "onboarding.step.notifications.title"
            }
        }

        var descKey: LocalizedStringKey {
            switch self {
            case .createHousehold:  return "onboarding.step.household.desc"
            case .firstAccount:     return "onboarding.step.account.desc"
            case .firstTransaction: return "onboarding.step.transaction.desc"
            case .firstBudget:      return "onboarding.step.budget.desc"
            case .firstGoalOrBill:  return "onboarding.step.goalOrBill.desc"
            case .notifications:    return "onboarding.step.notifications.desc"
            }
        }

        var icon: String {
            switch self {
            case .createHousehold:  return "house.fill"
            case .firstAccount:     return "creditcard.fill"
            case .firstTransaction: return "plus.circle.fill"
            case .firstBudget:      return "chart.pie.fill"
            case .firstGoalOrBill:  return "target"
            case .notifications:    return "bell.badge.fill"
            }
        }

        var ctaKey: LocalizedStringKey {
            switch self {
            case .createHousehold:  return "onboarding.step.household.cta"
            case .firstAccount:     return "onboarding.step.account.cta"
            case .firstTransaction: return "onboarding.step.transaction.cta"
            case .firstBudget:      return "onboarding.step.budget.cta"
            case .firstGoalOrBill:  return "onboarding.step.goalOrBill.cta"
            case .notifications:    return "onboarding.step.notifications.cta"
            }
        }
    }
}
