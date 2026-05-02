import Foundation
import SwiftUI
import UIKit
import PDFKit

/// Exportador PDF — reporte de transacciones con summary + tabla paginada.
///
/// Usa `ImageRenderer` (SwiftUI) para rasterizar cada página como UIImage, y
/// `UIGraphicsPDFRenderer` para empaquetarlas en un PDF multi-página.
///
/// Diseño A4/Letter vertical con summary (ingresos / gastos / balance) y
/// lista tabular paginada cada ~24 filas.
@MainActor
enum TransactionPDFExporter {
    /// Filas por página (calibrado para Letter 612x792 con el layout actual).
    private static let rowsPerPage = 24

    /// Tamaño de página — US Letter (612 × 792 points).
    /// Letter es más universal que A4 para exports compartidos con contador,
    /// especialmente para usuarios en US / LatAm.
    private static let pageSize = CGSize(width: 612, height: 792)

    static func export(
        transactions: [Transaction],
        householdName: String,
        householdCurrency: String,
        dateRange: (from: Date, to: Date),
        locale: Locale
    ) throws -> ExportedDocument {
        let pages = transactions.chunked(into: rowsPerPage)
        let totalPages = max(pages.count, 1)

        let (totalIngresos, totalGastos) = transactions.reduce(into: (Decimal(0), Decimal(0))) { acc, tx in
            if tx.type == .ingreso { acc.0 += tx.amount }
            else { acc.1 += tx.amount }
        }

        // Breakdown por categoría — solo GASTOS, ordenados descendente.
        // Mostramos top 10 y agrupamos el resto como "Otros".
        let categoryBreakdown = computeCategoryBreakdown(transactions: transactions)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let pdfData = pdfRenderer.pdfData { ctx in
            let iterPages: [[Transaction]] = pages.isEmpty ? [[]] : pages
            for (idx, pageRows) in iterPages.enumerated() {
                ctx.beginPage()

                let pageView = TransactionPDFPageView(
                    householdName: householdName,
                    currency: householdCurrency,
                    dateRange: dateRange,
                    totalIngresos: totalIngresos,
                    totalGastos: totalGastos,
                    categoryBreakdown: idx == 0 ? categoryBreakdown : [],
                    transactions: pageRows,
                    pageNumber: idx + 1,
                    totalPages: totalPages,
                    showSummary: idx == 0,
                    locale: locale
                )
                .frame(width: pageSize.width, height: pageSize.height)
                .environment(\.locale, locale)

                let renderer = ImageRenderer(content: pageView)
                renderer.proposedSize = ProposedViewSize(pageSize)
                if let uiImage = renderer.uiImage {
                    uiImage.draw(in: CGRect(origin: .zero, size: pageSize))
                }
            }
        }

        let fileName = makeFileName(householdName: householdName, dateRange: dateRange)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(ExportFormat.pdf.fileExtension)
        try pdfData.write(to: url, options: .atomic)

        return ExportedDocument(
            url: url,
            format: .pdf,
            fileName: url.lastPathComponent,
            byteCount: pdfData.count
        )
    }

    /// Agrupa gastos por categoría, calcula subtotal + %, y devuelve top 10
    /// + "Otros" si hay más. Se ordena descendente por monto.
    private static func computeCategoryBreakdown(transactions: [Transaction]) -> [CategoryBreakdownItem] {
        let expenses = transactions.filter { $0.type == .gasto }
        guard !expenses.isEmpty else { return [] }

        let totalExpenses = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        guard totalExpenses > 0 else { return [] }

        var grouped: [String: Decimal] = [:]
        for tx in expenses {
            grouped[tx.category, default: 0] += tx.amount
        }

        let sorted = grouped.map { CategoryBreakdownItem(category: $0.key, amount: $0.value, total: totalExpenses) }
            .sorted { $0.amount > $1.amount }

        let topLimit = 10
        if sorted.count <= topLimit { return sorted }

        let top = Array(sorted.prefix(topLimit))
        let rest = sorted.dropFirst(topLimit)
        let restTotal = rest.reduce(Decimal(0)) { $0 + $1.amount }
        let others = CategoryBreakdownItem(category: "Otros / Other", amount: restTotal, total: totalExpenses)
        return top + [others]
    }

    private static func makeFileName(householdName: String, dateRange: (from: Date, to: Date)) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        let slug = householdName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(.init(charactersIn: "-")))
            .joined()
        let from = fmt.string(from: dateRange.from)
        let to = fmt.string(from: dateRange.to)
        return "\(slug)-report-\(from)_\(to)"
    }
}

// MARK: - PDF Page View

/// Fila del breakdown por categoría en el PDF.
struct CategoryBreakdownItem: Hashable {
    let category: String
    let amount: Decimal
    let total: Decimal

    var percent: Double {
        let t = (total as NSDecimalNumber).doubleValue
        guard t > 0 else { return 0 }
        return (amount as NSDecimalNumber).doubleValue / t
    }
}

private struct TransactionPDFPageView: View {
    let householdName: String
    let currency: String
    let dateRange: (from: Date, to: Date)
    let totalIngresos: Decimal
    let totalGastos: Decimal
    let categoryBreakdown: [CategoryBreakdownItem]
    let transactions: [Transaction]
    let pageNumber: Int
    let totalPages: Int
    let showSummary: Bool
    let locale: Locale

    private var balance: Decimal { totalIngresos - totalGastos }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if showSummary { summary }
            if showSummary && !categoryBreakdown.isEmpty { breakdownSection }
            transactionsTable
            Spacer(minLength: 0)
            footer
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Color.black)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("app.name")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gray)
            Text(householdName)
                .font(.system(size: 22, weight: .bold))
            Text(rangeDescription)
                .font(.system(size: 11))
                .foregroundStyle(Color.gray)
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryTile(label: "Ingresos / Income", amount: totalIngresos, color: .green)
            summaryTile(label: "Gastos / Expenses", amount: totalGastos, color: .red, forceMinus: true)
            summaryTile(label: "Balance", amount: balance, color: balance >= 0 ? .green : .red)
        }
    }

    private func summaryTile(label: String, amount: Decimal, color: Color, forceMinus: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.gray)
                .textCase(.uppercase)
            Text(Money.format(forceMinus && amount > 0 ? -amount : amount, currency: currency, style: .compact, locale: locale))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(white: 0.96))
        .cornerRadius(6)
    }

    /// Sección "Gastos por categoría" con barra de progreso + monto + %
    /// para cada categoría (top 10 + "Otros"). Se muestra solo en la primera
    /// página del reporte.
    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gastos por categoría / Expenses by category")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.gray)
                .textCase(.uppercase)
                .padding(.bottom, 2)

            ForEach(categoryBreakdown, id: \.category) { item in
                HStack(spacing: 8) {
                    // Categoría con emoji
                    HStack(spacing: 4) {
                        Text(CategoryCatalog.emoji(for: item.category))
                        Text(item.category).font(.system(size: 10))
                    }
                    .frame(width: 160, alignment: .leading)

                    // Barra de progreso
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(white: 0.92))
                                .frame(height: 8)
                                .cornerRadius(2)
                            Rectangle()
                                .fill(Color.red.opacity(0.8))
                                .frame(width: geo.size.width * item.percent, height: 8)
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 8)

                    // Monto
                    Text(Money.format(-item.amount, currency: currency, style: .compact, locale: locale))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .frame(width: 95, alignment: .trailing)

                    // Porcentaje
                    Text(formatPercent(item.percent))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.gray)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(Color(white: 0.97))
        .cornerRadius(6)
    }

    private func formatPercent(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v * 100))%"
    }

    private var transactionsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Fecha").frame(width: 65, alignment: .leading)
                Text("Categoría").frame(width: 120, alignment: .leading)
                Text("Nota").frame(maxWidth: .infinity, alignment: .leading)
                Text("Monto").frame(width: 90, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.gray)
            .textCase(.uppercase)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 0.5)
            }

            ForEach(transactions.indices, id: \.self) { i in
                let tx = transactions[i]
                HStack(spacing: 8) {
                    Text(formatDate(tx.date)).frame(width: 65, alignment: .leading)
                    HStack(spacing: 4) {
                        Text(CategoryCatalog.emoji(for: tx.category))
                        Text(tx.category)
                    }
                    .frame(width: 120, alignment: .leading)
                    Text(tx.note ?? "")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text(formatAmount(tx))
                        .frame(width: 90, alignment: .trailing)
                        .foregroundStyle(tx.type == .gasto ? Color.red : Color.green)
                }
                .font(.system(size: 10))
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    if i < transactions.count - 1 {
                        Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 0.5)
                    }
                }
            }
        }
    }

    private var footer: some View {
        let app = String(localized: "app.name")
        return HStack {
            Text("pdf.footer.generatedWith \(app)")
                .font(.system(size: 8))
                .foregroundStyle(Color.gray)
            Spacer()
            Text("Página \(pageNumber) / \(totalPages)")
                .font(.system(size: 8))
                .foregroundStyle(Color.gray)
        }
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        // Postgres guarda transacción con tipo `date` = midnight UTC. Para que
        // la fecha renderizada matchee la que el usuario seleccionó en el
        // picker (sin shift de -3h en AR, por ej.) forzamos el formatter a UTC.
        f.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        f.setLocalizedDateFormatFromTemplate("ddMMM")
        return f.string(from: d)
    }

    private func formatAmount(_ tx: Transaction) -> String {
        let amt = tx.type == .gasto ? -tx.amount : tx.amount
        return Money.format(amt, currency: tx.currencyOriginal ?? currency, style: .compact, locale: locale)
    }

    private var rangeDescription: String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        f.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return "\(f.string(from: dateRange.from)) – \(f.string(from: dateRange.to))"
    }
}

// MARK: - Helpers

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
