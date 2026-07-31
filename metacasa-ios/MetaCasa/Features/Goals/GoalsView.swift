import SwiftUI
import Observation

@MainActor
@Observable
final class GoalsViewModel {
    var goals: [Goal] = []
    var isLoading = false
    var errorMessage: String?

    func load(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            goals = try await GoalService.shared.fetchAll(householdId: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAfter(_ op: () async throws -> Void, householdId: UUID) async {
        do {
            try await op()
            await load(householdId: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct GoalsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = GoalsViewModel()
    @State private var showAdd = false
    @State private var pendingFund: PendingFund?
    @State private var justCompletedGoal = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else if viewModel.goals.isEmpty {
                    ContentUnavailableView(
                        String(localized: "goals.empty"),
                        systemImage: "target",
                        description: Text("goals.empty.hint")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.goals) { g in
                                // La card envuelve DOS zonas tocables distintas: el contenido, que
                                // navega al detalle, y los chips de fondeo. Por eso el NavigationLink
                                // va adentro y no alrededor de todo — si envolviera los chips, cada
                                // toque en un monto navegaría en vez de aportar.
                                VStack(spacing: 0) {
                                    NavigationLink(destination: GoalDetailView(goal: g, onChange: reload)) {
                                        GoalRow(goal: g, currency: householdCurrency)
                                    }
                                    .buttonStyle(.plain)

                                    quickFundChips(for: g)
                                }
                                .mcCard()
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 12)
                    }
                    .refreshable { await reload() }
                }
            }
        }
        // El confeti va sobre toda la pantalla, no sobre la card: la meta cumplida es un momento
        // de la app entera, no de una fila. `ConfettiOverlay` ya existía sin usarse en ningún lado.
        .overlay { ConfettiOverlay(trigger: justCompletedGoal) }
        .confirmationDialog(
            Text("goals.fund.confirmTitle"),
            isPresented: Binding(get: { pendingFund != nil }, set: { if !$0 { pendingFund = nil } }),
            titleVisibility: .visible,
            presenting: pendingFund
        ) { fund in
            Button(Money.format(fund.amount, currency: fund.goal.currency)) {
                Task { await commit(fund) }
            }
            Button(role: .cancel) { pendingFund = nil } label: { Text("action.cancel") }
        } message: { fund in
            Text(verbatim: fund.goal.name)
        }
        .navigationTitle(Text("more.goals"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddGoalView { await reload() }
        }
        .task { await reload() }
    }

    // MARK: - Fondeo rápido

    /// Meta + monto esperando confirmación. Aportar mueve plata de verdad, así que no se
    /// commitea con el toque del chip: hace falta un segundo toque deliberado.
    private struct PendingFund: Identifiable {
        let goal: Goal
        let amount: Decimal
        var id: String { "\(goal.id)-\(amount)" }
    }

    @ViewBuilder
    private func quickFundChips(for goal: Goal) -> some View {
        let suggestions = GoalQuickFund.suggestions(current: goal.currentAmount, target: goal.targetAmount)
        // Sin sugerencias significa meta ya cumplida: mostrar chips ahí sería ofrecer pasarse de largo.
        if goal.status == .active && !suggestions.isEmpty {
            HStack(spacing: 8) {
                ForEach(suggestions) { s in
                    Button {
                        Haptics.play(.selection)
                        pendingFund = PendingFund(goal: goal, amount: s.amount)
                    } label: {
                        Text(s.completesGoal
                             ? String(localized: "goals.fund.complete")
                             : Money.format(s.amount, currency: goal.currency, style: .compact))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(s.completesGoal ? Color(hex: "#0E1312") : Color.textPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(
                                s.completesGoal ? Color.brandPrimary : Color.appSurfaceInset,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("goals.fund.a11y \(Money.format(s.amount, currency: goal.currency))"))
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
        }
    }

    private func commit(_ fund: PendingFund) async {
        pendingFund = nil
        guard let uid = appState.currentUserId else { return }
        do {
            _ = try await GoalService.shared.contribute(
                userId: uid, goalId: fund.goal.id, amount: fund.amount
            )
            // El total y el estado los actualiza el trigger de la DB, así que hay que releer
            // antes de decidir si celebrar — no alcanza con sumar en el cliente.
            await reload()
            let updated = viewModel.goals.first(where: { $0.id == fund.goal.id })
            if updated?.status == .completed {
                Haptics.play(.success)
                justCompletedGoal = true
                // Se rearma para que la próxima meta cumplida vuelva a disparar el overlay.
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    justCompletedGoal = false
                }
            } else {
                Haptics.play(.impactLight)
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private func reload() async {
        if let hid = appState.currentHouseholdId {
            await viewModel.load(householdId: hid)
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(goal.icon ?? "🎯").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name).font(.mcBody.weight(.bold)).foregroundStyle(Color.textPrimary)
                    if let d = goal.targetDate {
                        Text("Para \(d.formatted(date: .abbreviated, time: .omitted))")
                            .font(.mcCaption).foregroundStyle(Color.textMuted)
                    }
                }
                Spacer()
                if goal.status == .completed {
                    Label("OK", systemImage: "checkmark.seal.fill").labelStyle(.iconOnly)
                        .foregroundStyle(Color.brandSuccess)
                        .font(.title2)
                }
            }
            ProgressView(value: goal.progress)
                .tint(goal.status == .completed ? .brandSuccess : .brandPrimary)
            HStack {
                MoneyText(amount: goal.currentAmount, currency: goal.currency)
                    .font(.mcCaption).foregroundStyle(Color.textMuted)
                Text("/").font(.mcCaption).foregroundStyle(Color.textDim)
                MoneyText(amount: goal.targetAmount, currency: goal.currency)
                    .font(.mcCaption).foregroundStyle(Color.textMuted)
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(.mcCaption.weight(.bold))
                    .foregroundStyle(Color.brandPrimary)
            }
        }
        // La card la aplica el contenedor en GoalsView, porque envuelve también los chips de
        // fondeo rápido. Acá sólo va el contenido.
        .contentShape(Rectangle())
    }
}
