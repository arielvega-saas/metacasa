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

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else if viewModel.goals.isEmpty {
                    ContentUnavailableView(
                        "Sin metas todavía",
                        systemImage: "target",
                        description: Text("Tocá + para crear tu primera meta de ahorro.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.goals) { g in
                                NavigationLink(destination: GoalDetailView(goal: g, onChange: reload)) {
                                    GoalRow(goal: g, currency: householdCurrency)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 12)
                    }
                    .refreshable { await reload() }
                }
            }
        }
        .navigationTitle("Metas")
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
                Text(CurrencyFormatter.format(goal.currentAmount, currency: goal.currency))
                    .font(.mcCaption).foregroundStyle(Color.textMuted)
                Text("/").font(.mcCaption).foregroundStyle(Color.textDim)
                Text(CurrencyFormatter.format(goal.targetAmount, currency: goal.currency))
                    .font(.mcCaption).foregroundStyle(Color.textMuted)
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(.mcCaption.weight(.bold))
                    .foregroundStyle(Color.brandPrimary)
            }
        }
        .mcCard()
    }
}
