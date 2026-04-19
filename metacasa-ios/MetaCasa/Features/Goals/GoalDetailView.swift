import SwiftUI

struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Goal
    @State private var contributions: [GoalContribution] = []
    @State private var showContribute = false
    @State private var showDeleteConfirm = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onChange: () async -> Void

    init(goal: Goal, onChange: @escaping () async -> Void) {
        self._goal = State(initialValue: goal)
        self.onChange = onChange
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    progressCard
                    contributeButton
                    contributionsSection
                    deleteButton
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 40)
            }
            .refreshable { await loadContributions() }
        }
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadContributions() }
        .sheet(isPresented: $showContribute) {
            AddContributionView(goal: goal) { newContrib in
                await applyContribution(newContrib)
            }
        }
        .alert("¿Eliminar meta?", isPresented: $showDeleteConfirm) {
            Button("Eliminar", role: .destructive) {
                Task { await deleteGoal() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran todas las contribuciones registradas.")
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Text(goal.icon ?? "🎯").font(.system(size: 48))
            if goal.status == .completed {
                Label("Completada", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.brandSuccess)
                    .font(.mcH2)
            }
        }
        .frame(maxWidth: .infinity)
        .mcCard()
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                AmountLabel(amount: goal.currentAmount, currency: goal.currency, kind: .ingreso).font(.mcAmount)
                Spacer()
                Text("/").font(.mcH2).foregroundStyle(Color.textDim)
                AmountLabel(amount: goal.targetAmount, currency: goal.currency, kind: .neutro).font(.mcAmount)
            }
            ProgressView(value: goal.progress)
                .tint(goal.status == .completed ? .brandSuccess : .brandPrimary)
            HStack {
                Text("\(Int(goal.progress * 100))% completado").font(.mcCaption).foregroundStyle(Color.textMuted)
                Spacer()
                if let td = goal.targetDate {
                    Text("Hasta \(td.formatted(date: .abbreviated, time: .omitted))")
                        .font(.mcCaption).foregroundStyle(Color.textMuted)
                }
            }
        }
        .mcCard()
    }

    private var contributeButton: some View {
        Button {
            showContribute = true
        } label: {
            Label("Registrar aporte", systemImage: "plus.circle.fill")
        }
        .buttonStyle(MCPrimaryButton())
        .disabled(goal.status == .completed)
    }

    @ViewBuilder
    private var contributionsSection: some View {
        if contributions.isEmpty && !isLoading {
            Text("Aún no registraste aportes.")
                .font(.mcBody)
                .foregroundStyle(Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Aportes").font(.mcH2).foregroundStyle(Color.textPrimary)
                VStack(spacing: 0) {
                    ForEach(contributions.indices, id: \.self) { i in
                        let c = contributions[i]
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(Color.brandSuccess)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(CurrencyFormatter.format(c.amount, currency: goal.currency))
                                    .font(.mcBody.weight(.bold)).foregroundStyle(Color.textPrimary)
                                Text(c.contributedAt, format: .dateTime.day().month(.abbreviated).year())
                                    .font(.mcCaption).foregroundStyle(Color.textMuted)
                            }
                            Spacer()
                            if let n = c.notes, !n.isEmpty {
                                Text(n).font(.mcCaption).foregroundStyle(Color.textMuted).lineLimit(2)
                            }
                        }
                        .padding(.vertical, 10)
                        if i < contributions.count - 1 {
                            Divider().background(Color.appBorder)
                        }
                    }
                }
                .mcCard()
            }
        }
    }

    private var deleteButton: some View {
        Button("Eliminar meta", role: .destructive) {
            showDeleteConfirm = true
        }
        .padding(.top, 24)
    }

    @MainActor
    private func loadContributions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            contributions = try await GoalService.shared.fetchContributions(goalId: goal.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func applyContribution(_ contrib: GoalContribution) async {
        // El trigger SQL ya actualizó goal.current_amount y status.
        // Volvemos a leer los contributions y actualizamos local.
        goal.currentAmount += contrib.amount
        if goal.currentAmount >= goal.targetAmount && goal.status == .active {
            goal.status = .completed
            goal.completedAt = goal.completedAt ?? Date()
        }
        await loadContributions()
        await onChange()
    }

    @MainActor
    private func deleteGoal() async {
        do {
            try await GoalService.shared.delete(id: goal.id)
            await onChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
