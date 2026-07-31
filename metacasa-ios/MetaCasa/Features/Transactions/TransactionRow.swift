import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    let currency: String
    var accountName: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(CategoryCatalog.emoji(for: transaction.category))
                .font(.system(size: 22))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.appSurfaceInset))

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.mcBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(transaction.category)
                    if let detail = secondaryDetail {
                        Text("·")
                        Text(detail)
                    }
                }
                .font(.mcCaption)
                .foregroundStyle(Color.textMuted)
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                AmountLabel(
                    amount: transaction.amount,
                    currency: transaction.currencyOriginal ?? currency,
                    kind: transaction.type == .gasto ? .gasto : .ingreso
                )
                .font(.mcBody.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.textDim)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var displayTitle: String {
        if let n = transaction.note, !n.isEmpty { return n }
        return transaction.category
    }

    private var secondaryDetail: String? {
        if let subcategory = transaction.subcategory, !subcategory.isEmpty {
            return subcategory
        }
        if let accountName, !accountName.isEmpty {
            return accountName
        }
        if let legacyAccount = transaction.account, !legacyAccount.isEmpty {
            return legacyAccount
        }
        return nil
    }
}
