import SwiftUI

/// Detalle de un plan de cuotas con ledger mes a mes.
struct InstallmentDetailView: View {
    let plan: InstallmentPlan
    let onChange: () -> Void

    @State private var payments: [InstallmentPayment] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    header
                    progressCard
                    paymentsCard
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .refreshable { await load() }
        }
        .navigationTitle(plan.name)
        .task { await load() }
    }

    private var paidCount: Int { payments.filter { $0.paid }.count }
    private var progressRatio: Double {
        guard plan.totalInstallments > 0 else { return 0 }
        return Double(paidCount) / Double(plan.totalInstallments)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("installments.detail.monthly").font(.mcLabel).foregroundStyle(Color.textMuted)
                Spacer()
            }
            AmountLabel(amount: plan.monthlyAmount, currency: plan.currency, kind: .gasto)
                .font(.mcDisplay)
            HStack {
                Label {
                    Text("installments.detail.total")
                } icon: {
                    Image(systemName: "sum")
                }
                .font(.caption).foregroundStyle(.secondary)
                Spacer()
                AmountLabel(amount: plan.totalAmount, currency: plan.currency, kind: .neutro)
                    .font(.caption)
            }
        }
        .mcCard()
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("installments.progress \(paidCount) \(plan.totalInstallments)")
                    .font(.mcLabel).foregroundStyle(Color.textMuted)
                Spacer()
                Text("\(Int(progressRatio * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(progressRatio >= 1 ? Color.brandSuccess : Color.brandPrimary)
            }
            ProgressView(value: progressRatio)
                .tint(progressRatio >= 1 ? .brandSuccess : .brandPrimary)
        }
        .mcCard()
    }

    private var paymentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("installments.detail.ledger")
                .font(.mcH2)
                .foregroundStyle(Color.textPrimary)
            ForEach(payments, id: \.id) { pay in
                HStack(spacing: 10) {
                    Image(systemName: pay.paid ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(pay.paid ? Color.brandSuccess : Color.secondary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("installments.detail.month \(pay.installmentNumber) \(String(format: "%02d/%d", pay.periodMonth, pay.periodYear))")
                            .font(.subheadline.weight(.semibold))
                        if pay.paid, let date = pay.paidAt {
                            Text("installments.detail.paidAt \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    AmountLabel(amount: pay.amount, currency: plan.currency, kind: .gasto)
                        .font(.subheadline.weight(.bold))
                    if !pay.paid {
                        Button {
                            Task { await markPaid(pay) }
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(Color.brandPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                if pay.id != payments.last?.id {
                    Divider()
                }
            }
        }
        .mcCard()
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        payments = (try? await InstallmentService.shared.fetchPayments(planId: plan.id)) ?? []
    }

    @MainActor
    private func markPaid(_ pay: InstallmentPayment) async {
        try? await InstallmentService.shared.markPaymentPaid(id: pay.id)
        await load()
        onChange()
    }
}
