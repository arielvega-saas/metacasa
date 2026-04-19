import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    let currency: String

    var body: some View {
        HStack(spacing: 14) {
            Text(CategoryCatalog.emoji(for: transaction.category))
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.05))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.mcBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(transaction.date, format: .dateTime.day().month(.abbreviated))
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()

            AmountLabel(
                amount: transaction.amount,
                currency: transaction.currencyOriginal ?? currency,
                kind: transaction.type == .gasto ? .gasto : .ingreso
            )
            .font(.mcBody.weight(.bold))
        }
        .padding(.vertical, 12)
    }

    private var displayTitle: String {
        if let n = transaction.note, !n.isEmpty { return n }
        return transaction.category
    }
}
