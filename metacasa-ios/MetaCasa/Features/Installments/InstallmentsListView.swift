import SwiftUI

/// Lista de planes de cuotas con resumen de progreso y navegación al detalle.
struct InstallmentsListView: View {
    @Environment(AppState.self) private var appState
    @State private var plans: [InstallmentPlan] = []
    @State private var progressByPlan: [UUID: (paid: Int, total: Int)] = [:]
    @State private var showAdd = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if isLoading && plans.isEmpty {
                    ProgressView().tint(.white)
                } else if plans.isEmpty {
                    ContentUnavailableView(
                        String(localized: "installments.empty.title"),
                        systemImage: "creditcard.and.123",
                        description: Text("installments.empty.hint")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(plans) { plan in
                                NavigationLink {
                                    InstallmentDetailView(plan: plan, onChange: { Task { await load() } })
                                } label: {
                                    PlanRow(
                                        plan: plan,
                                        progress: progressByPlan[plan.id] ?? (0, plan.totalInstallments)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 12)
                    }
                }
            }
        }
        .navigationTitle(Text("more.installments"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddInstallmentPlanView { await load() }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor
    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            plans = try await InstallmentService.shared.fetchPlans(householdId: hid)
            var progress: [UUID: (paid: Int, total: Int)] = [:]
            for p in plans {
                let payments = (try? await InstallmentService.shared.fetchPayments(planId: p.id)) ?? []
                let paid = payments.filter { $0.paid }.count
                progress[p.id] = (paid, p.totalInstallments)
            }
            progressByPlan = progress
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - PlanRow

private struct PlanRow: View {
    let plan: InstallmentPlan
    let progress: (paid: Int, total: Int)

    private var progressRatio: Double {
        guard progress.total > 0 else { return 0 }
        return Double(progress.paid) / Double(progress.total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.mcBody.weight(.bold))
                        .foregroundStyle(Color.textPrimary)
                    if let cat = plan.category {
                        Text(cat).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    AmountLabel(amount: plan.monthlyAmount, currency: plan.currency, kind: .gasto)
                        .font(.mcBody.weight(.bold))
                    Text("installments.monthly")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: progressRatio)
                .tint(progressRatio >= 1 ? .brandSuccess : .brandPrimary)
            HStack {
                Text("installments.progress \(progress.paid) \(progress.total)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                AmountLabel(amount: plan.totalAmount, currency: plan.currency, kind: .neutro)
                    .font(.caption).foregroundStyle(Color.textMuted)
            }
        }
        .mcCard()
    }
}
