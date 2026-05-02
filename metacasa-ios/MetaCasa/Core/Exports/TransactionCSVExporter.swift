import Foundation

/// Exportador CSV de transacciones — **full dataset** para análisis / reportes.
///
/// ### Formato del archivo
/// - **RFC 4180 compliant**: separador `,`, valores con `,` / `"` / newline se
///   envuelven en `"..."` con `""` como escape de comillas.
/// - **UTF-8 BOM**: primer byte = `\u{FEFF}` para que Excel en Windows detecte
///   el encoding correctamente (sin BOM rompe tildes y eñes).
/// - **Decimal universal**: amounts siempre con `.` como separador decimal y
///   sin agrupamiento de miles. Ignora el locale del usuario a propósito —
///   maximiza interoperabilidad con Excel/Sheets/Numbers en cualquier país
///   (ADR-006 en PROJECT_CONTEXT.md).
///
/// ### Columnas (21 total)
/// Incluye TODO lo útil para armar reportes, pivot tables, análisis temporal
/// y trazabilidad. Un analista o contador típico puede importar a Excel/Sheets
/// y pivotar directamente.
///
/// | # | Columna | Descripción |
/// |---|---------|-------------|
/// | 1 | id | UUID de la transacción |
/// | 2 | date | ISO 8601 (YYYY-MM-DD) |
/// | 3 | year | año (para pivot) |
/// | 4 | month | mes 1–12 (para pivot) |
/// | 5 | day | día del mes |
/// | 6 | weekday | día de semana 1=Dom … 7=Sáb |
/// | 7 | type | `expense` / `income` |
/// | 8 | signed_amount | negativo para gastos, positivo para ingresos |
/// | 9 | amount | valor absoluto |
/// | 10 | currency | código ISO 4217 |
/// | 11 | amount_base | monto convertido a moneda base del hogar (si hay FX) |
/// | 12 | currency_base | moneda base del hogar |
/// | 13 | fx_rate | tasa usada en la conversión |
/// | 14 | fx_source | fuente del rate (oficial, blue, manual) |
/// | 15 | fx_status | estado (applied / pending / na) |
/// | 16 | category | categoría |
/// | 17 | subcategory | subcategoría |
/// | 18 | note | nota libre |
/// | 19 | account | nombre de la cuenta (texto libre en DB) |
/// | 20 | account_id | UUID de la cuenta (para join externo) |
/// | 21 | user_id | quién registró la tx (multi-user households) |
/// | 22 | household_id | UUID del hogar |
/// | 23 | created_at | timestamp de creación en DB |
enum TransactionCSVExporter {

    static func export(
        transactions: [Transaction],
        householdName: String,
        householdCurrency: String,
        dateRange: (from: Date, to: Date),
        locale: Locale
    ) throws -> ExportedDocument {
        let csv = buildCSV(
            transactions: transactions,
            householdCurrency: householdCurrency
        )

        let fileName = makeFileName(householdName: householdName, dateRange: dateRange)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(ExportFormat.csv.fileExtension)

        // BOM para compat Excel en Windows/Mac legacy.
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(csv.data(using: .utf8) ?? Data())
        try data.write(to: url, options: .atomic)

        return ExportedDocument(
            url: url,
            format: .csv,
            fileName: url.lastPathComponent,
            byteCount: data.count
        )
    }

    // MARK: - CSV building

    private static let columns = [
        "id",
        "date",
        "year",
        "month",
        "day",
        "weekday",
        "type",
        "signed_amount",
        "amount",
        "currency",
        "amount_base",
        "currency_base",
        "fx_rate",
        "fx_source",
        "fx_status",
        "category",
        "subcategory",
        "note",
        "account",
        "account_id",
        "user_id",
        "household_id",
        "created_at"
    ]

    private static func buildCSV(
        transactions: [Transaction],
        householdCurrency: String
    ) -> String {
        var lines: [String] = []
        lines.append(columns.joined(separator: ","))

        let isoDate = ISO8601DateFormatter()
        isoDate.formatOptions = [.withFullDate]

        let isoDateTime = ISO8601DateFormatter()
        isoDateTime.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Calendar en UTC para que los componentes (year/month/day/weekday) matcheen
        // con la fecha que guarda Postgres (tipo `date` = midnight UTC). Si usamos
        // `Calendar.current` en un device -3h (AR), midnight UTC del 18-abr se
        // convierte a 17-abr 21:00 local → day extraído = 17. Error clásico.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt

        for tx in transactions {
            let type = tx.type == .gasto ? "expense" : "income"
            let signedAmount = tx.type == .gasto ? -tx.amount : tx.amount

            // Montos en moneda base del hogar
            let (amountBase, baseCurrency) = resolveBaseAmount(
                tx: tx,
                householdCurrency: householdCurrency
            )

            // Componentes temporales (útiles para pivots sin formulas)
            let components = cal.dateComponents([.year, .month, .day, .weekday], from: tx.date)
            let year = components.year.map(String.init) ?? ""
            let month = components.month.map(String.init) ?? ""
            let day = components.day.map(String.init) ?? ""
            let weekday = components.weekday.map(String.init) ?? ""

            let row: [String] = [
                tx.id.uuidString,
                isoDate.string(from: tx.date),
                year,
                month,
                day,
                weekday,
                type,
                formatAmount(signedAmount),
                formatAmount(tx.amount),
                tx.currencyOriginal ?? householdCurrency,
                amountBase.map(formatAmount) ?? "",
                baseCurrency,
                tx.fxRateToBase.map(formatAmount) ?? "",
                tx.fxSource ?? "",
                tx.fxStatus ?? "",
                tx.category,
                tx.subcategory ?? "",
                tx.note ?? "",
                tx.account ?? "",
                tx.accountId?.uuidString ?? "",
                tx.userId.uuidString,
                tx.householdId.uuidString,
                tx.createdAt.map(isoDateTime.string(from:)) ?? ""
            ]
            lines.append(row.map(escape).joined(separator: ","))
        }

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Si la transacción tiene FX aplicado, calcula amount * fx_rate_to_base.
    /// Si no, devuelve el amount tal cual con la currency del hogar.
    private static func resolveBaseAmount(
        tx: Transaction,
        householdCurrency: String
    ) -> (amount: Decimal?, currency: String) {
        let txCurrency = tx.currencyOriginal ?? householdCurrency

        // Caso 1: la tx está en la moneda base del hogar → no hace falta FX.
        if txCurrency == householdCurrency {
            return (tx.amount, householdCurrency)
        }

        // Caso 2: hay rate a base explícito → aplicar.
        if let rate = tx.fxRateToBase {
            return (tx.amount * rate, householdCurrency)
        }

        // Caso 3: distinta moneda pero sin rate (pendiente de conciliación).
        return (nil, householdCurrency)
    }

    /// Formato numérico UNIVERSAL: `.` decimal, sin miles, 2 decimales fijos.
    /// No respeta el locale deliberadamente — maximiza interoperabilidad.
    private static func formatAmount(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.decimalSeparator = "."
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// RFC 4180 escape: envolver en `"..."` si el valor contiene `,`, `"`, CR o LF.
    /// Dentro, `"` se duplica (`""`).
    private static func escape(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") else {
            return s
        }
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
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
        return "\(slug)-transactions-\(from)_\(to)"
    }
}
