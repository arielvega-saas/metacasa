import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    let currency: String

    /// Tinte derivado del tipo de transacción. Gastos coral, ingresos sage.
    /// Da identidad visual al icono sin necesitar mapeo de color por categoría.
    private var tintColor: Color {
        transaction.type == .gasto ? .brandDanger : .brandSuccess
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(CategoryCatalog.emoji(for: transaction.category))
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(Circle().fill(tintColor.opacity(0.12)))
                .overlay(Circle().stroke(tintColor.opacity(0.30), lineWidth: 1))

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
