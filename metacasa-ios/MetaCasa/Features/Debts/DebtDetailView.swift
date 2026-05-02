import SwiftUI

struct DebtDetailView: View {
    let debt: Debt
    let onChange: () -> Void

    @State private var showEdit = false
    @State private var showSettleConfirm = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    balanceCard
                    interestCard
                    projectionCard
                    notesCard
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
        .navigationTitle(debt.creditor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("action.edit", systemImage: "pencil")
                    }
                    if debt.status == .active {
                        Button(role: .destructive) {
                            showSettleConfirm = true
                        } label: {
                            Label("debts.settle", systemImage: "checkmark.circle.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddDebtView(editing: debt) {
                onChange()
            }
        }
        .confirmationDialog("debts.settle.confirm", isPresented: $showSettleConfirm, titleVisibility: .visible) {
            Button("debts.settle", role: .destructive) {
                Task {
                    try? await DebtService.shared.settle(id: debt.id)
                    onChange()
                }
            }
            Button("action.cancel", role: .cancel) {}
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("debts.detail.balance").font(.mcLabel).foregroundStyle(Color.textMuted)
            AmountLabel(amount: debt.currentBalance, currency: debt.currency, kind: .gasto)
                .font(.mcDisplay)
            HStack {
                Text("debts.detail.original").font(.caption).foregroundStyle(.secondary)
                Spacer()
                AmountLabel(amount: debt.originalAmount, currency: debt.currency, kind: .neutro)
                    .font(.caption)
            }
            ProgressView(value: debt.progress)
                .tint(Color.brandPrimary)
            Text("\(Int(debt.progress * 100))% debts.detail.paid")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .mcCard()
    }

    private var interestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("debts.detail.interest").font(.mcLabel)
            } icon: {
                Image(systemName: "percent")
            }
            .foregroundStyle(Color.textMuted)
            HStack {
                Text("debts.detail.annualRate")
                Spacer()
                Text("\(fmt(debt.annualRate))%")
                    .font(.body.weight(.bold))
            }
            HStack {
                Text("debts.detail.monthlyInterest")
                Spacer()
                AmountLabel(amount: debt.estimatedMonthlyInterest, currency: debt.currency, kind: .gasto)
                    .font(.subheadline.weight(.bold))
            }
            if let mp = debt.monthlyPayment {
                HStack {
                    Text("debts.detail.monthlyPayment")
                    Spacer()
                    AmountLabel(amount: mp, currency: debt.currency, kind: .gasto)
                        .font(.subheadline.weight(.bold))
                }
            }
        }
        .mcCard()
    }

    private var projectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("debts.detail.projection").font(.mcLabel)
            } icon: {
                Image(systemName: "calendar.badge.clock")
            }
            .foregroundStyle(Color.textMuted)

            if let months = debt.estimatedMonthsToPayoff {
                let years = months / 12
                let rem = months % 12
                HStack {
                    Text("debts.detail.payoffIn")
                    Spacer()
                    Text(years > 0 ? "\(years)a \(rem)m" : "\(rem)m")
                        .font(.body.weight(.bold))
                }
                if let payoffDate = Calendar.current.date(byAdding: .month, value: months, to: Date()) {
                    HStack {
                        Text("debts.detail.payoffDate")
                        Spacer()
                        Text(payoffDate, format: .dateTime.month(.wide).year())
                            .font(.body.weight(.bold))
                    }
                }
            } else {
                Text("debts.detail.noPayoff")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let days = debt.daysUntilMaturity, let mat = debt.maturityDate {
                Divider().padding(.vertical, 4)
                HStack {
                    Text("debts.detail.maturity")
                    Spacer()
                    Text(mat, format: .dateTime.day().month(.wide).year())
                        .font(.caption)
                }
                if days < 0 {
                    Text("debts.detail.overdue")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.brandDanger)
                } else {
                    Text("debts.detail.daysLeft \(days)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .mcCard()
    }

    @ViewBuilder
    private var notesCard: some View {
        if let note = debt.note, !note.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("tx.field.note").font(.mcLabel).foregroundStyle(Color.textMuted)
                Text(note).font(.mcBody).foregroundStyle(Color.textPrimary)
            }
            .mcCard()
        }
    }

    private func fmt(_ d: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2; nf.minimumFractionDigits = 0
        return nf.string(from: d as NSDecimalNumber) ?? "\(d)"
    }
}
