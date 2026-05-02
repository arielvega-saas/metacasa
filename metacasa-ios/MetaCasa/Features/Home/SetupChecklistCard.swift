import SwiftUI

/// Widget del Home que muestra un checklist de setup para usuarios nuevos.
///
/// Comportamiento:
/// - Se muestra solo si `OnboardingProgress.shouldShow == true`.
/// - Cada step sin completar es tappable y abre la pantalla correspondiente
///   como sheet.
/// - Progress ring + checkmarks visuales con animación.
/// - Ícono "xmark" arriba-derecha permite dismiss permanente (alert de confirm).
///
/// Paridad con el patrón de onboarding de apps financieras (Cashew, Monarch,
/// YNAB) que guían al user por los primeros pasos de setup.
struct SetupChecklistCard: View {
    @Environment(OnboardingProgress.self) private var onboarding
    @Environment(AppState.self) private var appState

    @State private var showDismissConfirm = false
    @State private var activeRoute: SetupRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().overlay(Color.appBorder.opacity(0.5))
            VStack(spacing: 10) {
                ForEach(onboarding.steps) { step in
                    stepRow(step)
                }
            }
        }
        .mcCard()
        .confirmationDialog(
            Text("onboarding.dismissConfirm.title"),
            isPresented: $showDismissConfirm,
            titleVisibility: .visible
        ) {
            Button("onboarding.dismissConfirm.confirm", role: .destructive) {
                onboarding.dismissForever()
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("onboarding.dismissConfirm.message")
        }
        .sheet(item: $activeRoute, onDismiss: {
            Task { await onboarding.refresh(appState: appState) }
        }) { route in
            routeDestination(route)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.appBorder, lineWidth: 4)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: onboarding.progress)
                    .stroke(
                        Color.brandPrimary,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                    .animation(.easeOut(duration: 0.6), value: onboarding.progress)
                Text("\(onboarding.doneCount)/\(onboarding.steps.count)")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(Color.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("onboarding.title")
                    .font(.mcH2)
                    .foregroundStyle(Color.textPrimary)
                Text("onboarding.subtitle")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                showDismissConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 30, height: 30)
                    .background(Color.appSurfaceInset)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("onboarding.dismiss"))
        }
    }

    private func stepRow(_ step: SetupStep) -> some View {
        Button {
            handleTap(step: step)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(step.isDone ? Color.brandPrimary.opacity(0.15) : Color.appSurfaceInset)
                        .frame(width: 34, height: 34)
                    Image(systemName: step.isDone ? "checkmark" : step.id.icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(step.isDone ? Color.brandPrimary : Color.textMuted)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.id.titleKey)
                        .font(.mcBody.weight(step.isDone ? .regular : .semibold))
                        .foregroundStyle(step.isDone ? Color.textMuted : Color.textPrimary)
                        .strikethrough(step.isDone, color: Color.textMuted)
                    Text(step.id.descKey)
                        .font(.mcCaption)
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(2)
                }
                Spacer()
                if !step.isDone {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textDim)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(step.isDone)
    }

    // MARK: - Actions

    private func handleTap(step: SetupStep) {
        Haptics.play(.selection)
        switch step.id {
        case .createHousehold:
            // Siempre done si hay appState.currentHouseholdId. No-op.
            break
        case .firstAccount:
            activeRoute = .addAccount
        case .firstTransaction:
            activeRoute = .addTransaction
        case .firstBudget:
            activeRoute = .budget
        case .firstGoalOrBill:
            activeRoute = .addGoal
        case .notifications:
            Task {
                _ = await NotificationService.shared.requestAuthorization()
                await onboarding.refresh(appState: appState)
            }
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: SetupRoute) -> some View {
        switch route {
        case .addAccount:
            NavigationStack {
                AddAccountView(onSaved: {
                    await onboarding.refresh(appState: appState)
                })
            }
        case .addTransaction:
            AddTransactionView()
        case .addGoal:
            NavigationStack {
                AddGoalView(onSaved: {
                    await onboarding.refresh(appState: appState)
                })
            }
        case .budget:
            BudgetHubView()
        }
    }
}

/// Rutas que el checklist puede abrir como sheet.
enum SetupRoute: String, Identifiable {
    case addAccount
    case addTransaction
    case addGoal
    case budget
    var id: String { rawValue }
}
