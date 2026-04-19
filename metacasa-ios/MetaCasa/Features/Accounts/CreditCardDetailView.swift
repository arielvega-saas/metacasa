import SwiftUI

struct CreditCardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let account: Account

    @State private var details: CreditCardDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView().tint(.white).padding(40)
                    } else if let d = details {
                        limitCard(d)
                        dueCard(d)
                        interestCard(d)
                    } else {
                        Text("Esta cuenta no tiene detalles de TC cargados.")
                            .font(.mcBody).foregroundStyle(Color.textMuted)
                            .padding(.vertical, 24)
                    }
                    if let msg = errorMessage {
                        Text(msg).font(.mcCaption).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func limitCard(_ d: CreditCardDetails) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LÍMITE").font(.mcLabel).foregroundStyle(Color.textMuted)
            AmountLabel(amount: d.creditLimit, currency: account.currency, kind: .neutro).font(.mcDisplay)
            Text("Red: \(d.network?.rawValue.uppercased() ?? "—")")
                .font(.mcCaption).foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    private func dueCard(_ d: CreditCardDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VENCIMIENTO").font(.mcLabel).foregroundStyle(Color.textMuted)
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Cierre").font(.mcCaption).foregroundStyle(Color.textMuted)
                    Text("Día \(d.statementDay)").font(.mcH2).foregroundStyle(Color.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Vence").font(.mcCaption).foregroundStyle(Color.textMuted)
                    Text("Día \(d.dueDay)").font(.mcH2).foregroundStyle(Color.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    let days = CreditCardService.daysUntilDue(dueDay: d.dueDay)
                    Text("En").font(.mcCaption).foregroundStyle(Color.textMuted)
                    Text("\(days)d").font(.mcH2).foregroundStyle(days <= 5 ? Color.brandDanger : Color.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    private func interestCard(_ d: CreditCardDetails) -> some View {
        let stmt = d.lastStatementAmount ?? 0
        let minPay = CreditCardService.minimumPayment(statementAmount: stmt, percent: d.minimumPaymentPct)
        let interestIfMin = CreditCardService.interestIfMinPayment(
            statementAmount: stmt,
            minPct: d.minimumPaymentPct,
            monthlyRate: d.interestRateMonthly
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text("SALDO DEL RESUMEN").font(.mcLabel).foregroundStyle(Color.textMuted)
            AmountLabel(amount: stmt, currency: account.currency, kind: .gasto).font(.mcAmount)

            Divider().background(Color.appBorder).padding(.vertical, 6)

            HStack {
                Text("Mínimo (\(formatPct(d.minimumPaymentPct)))").font(.mcCaption).foregroundStyle(Color.textMuted)
                Spacer()
                Text(CurrencyFormatter.format(minPay, currency: account.currency))
                    .font(.mcBody.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
            }
            HStack {
                Text("Interés si pagás solo el mínimo (\(formatPct(d.interestRateMonthly))/mes)")
                    .font(.mcCaption).foregroundStyle(Color.textMuted)
                Spacer()
                Text(CurrencyFormatter.format(interestIfMin, currency: account.currency))
                    .font(.mcBody.weight(.bold))
                    .foregroundStyle(Color.brandDanger)
            }

            if let date = d.lastStatementDate {
                Text("Último resumen: \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.mcCaption).foregroundStyle(Color.textDim).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    private func formatPct(_ d: Decimal) -> String {
        let fmt = NumberFormatter()
        fmt.maximumFractionDigits = 2
        return (fmt.string(from: d as NSDecimalNumber) ?? "\(d)") + "%"
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            details = try await CreditCardService.shared.fetchDetails(accountId: account.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
