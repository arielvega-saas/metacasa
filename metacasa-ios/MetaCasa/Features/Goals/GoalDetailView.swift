import SwiftUI

struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Goal
    @State private var contributions: [GoalContribution] = []
    @State private var showContribute = false
    @State private var showDeleteConfirm = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var justCompleted = false

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
        .overlay { ConfettiOverlay(trigger: justCompleted) }
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
            HStack(alignment: .firstTextBaseline) {
                AmountLabel(amount: goal.currentAmount, currency: goal.currency, kind: .ingreso).font(.mcSerifAmount)
                Spacer()
                Text("/").font(.mcSerifTitle).foregroundStyle(Color.textDim)
                AmountLabel(amount: goal.targetAmount, currency: goal.currency, kind: .neutro).font(.mcSerifAmount)
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

            // ETA: a ritmo actual, cuánto falta
            if let eta = etaText, goal.status != .completed {
                Divider().padding(.vertical, 4)
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Color.brandPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("goal.eta.label").font(.caption2.weight(.bold)).foregroundStyle(Color.textMuted)
                        Text(eta).font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                    }
                    Spacer()
                }
            }
        }
        .mcCard()
    }

    /// Texto de ETA estimado según aporte promedio mensual.
    /// - Si hay targetDate: muestra días restantes + ritmo necesario
    /// - Si no: estima cuántos meses quedan a ritmo actual
    private var etaText: String? {
        let remaining = max(0, goal.targetAmount - goal.currentAmount)
        guard remaining > 0 else { return nil }

        // Aporte promedio mensual (basado en contribuciones existentes).
        let cal = Calendar.current
        guard let firstContrib = contributions.map({ $0.contributedAt }).min() else {
            // Sin contribuciones aún. Si hay targetDate, calcular ritmo requerido.
            if let td = goal.targetDate {
                let days = max(1, cal.dateComponents([.day], from: Date(), to: td).day ?? 0)
                let monthlyNeeded = remaining * 30 / Decimal(days)
                return String(
                    format: String(localized: "goal.eta.needMonthly %@ %d"),
                    Money.format(monthlyNeeded, currency: goal.currency, style: .compact),
                    days
                )
            }
            return nil
        }

        let daysSinceFirst = max(1, cal.dateComponents([.day], from: firstContrib, to: Date()).day ?? 1)
        let totalContrib = contributions.reduce(Decimal(0)) { $0 + $1.amount }
        // Avg per month = total × 30 / days
        let avgMonthly = totalContrib * 30 / Decimal(daysSinceFirst)

        guard avgMonthly > 0 else {
            return String(localized: "goal.eta.noPace")
        }

        let monthsToGo = (remaining as NSDecimalNumber).doubleValue / (avgMonthly as NSDecimalNumber).doubleValue

        if let td = goal.targetDate {
            let daysLeft = cal.dateComponents([.day], from: Date(), to: td).day ?? 0
            let monthsLeft = Double(daysLeft) / 30.0
            if monthsToGo <= monthsLeft {
                return String(
                    format: String(localized: "goal.eta.onTrack %d"),
                    Int(ceil(monthsToGo))
                )
            } else {
                return String(
                    format: String(localized: "goal.eta.offTrack %d %d"),
                    Int(ceil(monthsToGo)),
                    daysLeft
                )
            }
        }

        return String(
            format: String(localized: "goal.eta.estimated %d %@"),
            Int(ceil(monthsToGo)),
            Money.format(avgMonthly, currency: goal.currency, style: .compact)
        )
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
                                // `.ingreso`: cada aporte a la meta es dinero
                                // que ENTRA al ahorro → verde, consistente con
                                // la convención de income en el resto de la app.
                                AmountLabel(amount: c.amount, currency: goal.currency, kind: .ingreso)
                                    .font(.mcBody.weight(.bold))
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
        let wasActive = goal.status == .active
        goal.currentAmount += contrib.amount
        if goal.currentAmount >= goal.targetAmount && goal.status == .active {
            goal.status = .completed
            goal.completedAt = goal.completedAt ?? Date()
            if wasActive {
                // 🎉 dispara confetti + success haptic
                Haptics.play(.success)
                justCompleted = true
                // Reset flag para poder re-disparar si contribuyen sobre meta ya completa
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    justCompleted = false
                }
            }
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
