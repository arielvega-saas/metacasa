import Foundation

/// Representación lógica de un campo de transacción que podemos mapear desde
/// un CSV externo. El usuario elige (o la heurística detecta) qué columna
/// del CSV corresponde a cada uno.
enum TxField: String, CaseIterable, Identifiable, Hashable {
    case ignore          // No importar esta columna
    case date
    case type            // "expense"/"income", "gasto"/"ingreso", +/-
    case amount          // positivo siempre; usar `type` para decidir signo
    case signedAmount    // negativo=gasto, positivo=ingreso (alternativa a amount+type)
    case currency
    case category
    case subcategory
    case note
    case account

    var id: String { rawValue }

    /// Label amigable para el UI de mapeo.
    var label: String {
        switch self {
        case .ignore:       return "Ignorar"
        case .date:         return "Fecha"
        case .type:         return "Tipo (gasto/ingreso)"
        case .amount:       return "Monto (absoluto)"
        case .signedAmount: return "Monto con signo (+/-)"
        case .currency:     return "Moneda"
        case .category:     return "Categoría"
        case .subcategory:  return "Subcategoría"
        case .note:         return "Nota"
        case .account:      return "Cuenta"
        }
    }

    /// Heurística: adivinar qué campo corresponde a un header CSV.
    /// Los nombres comunes de bancos/apps latam + US se mapean automáticamente.
    static func guess(from header: String) -> TxField {
        let h = header.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        // Date
        if h.contains("date") || h.contains("fecha") || h == "dt" || h == "día" || h == "dia" {
            return .date
        }
        // Type
        if h.contains("type") || h.contains("tipo") || h == "kind" {
            return .type
        }
        // Signed amount
        if h.contains("signed") || h.contains("signo") || h == "value" || h == "valor" {
            return .signedAmount
        }
        // Amount
        if h.contains("amount") || h.contains("monto") || h.contains("importe") || h == "abs" {
            return .amount
        }
        // Currency
        if h.contains("currency") || h.contains("moneda") || h == "cur" || h == "iso" {
            return .currency
        }
        // Subcategory — CHECK BEFORE category para que no matchee antes.
        if h.contains("subcategory") || h.contains("subcategoria") || h.contains("subcategoría") {
            return .subcategory
        }
        // Category
        if h.contains("category") || h.contains("categoria") || h.contains("categoría") || h.contains("rubro") {
            return .category
        }
        // Note / memo / description
        if h.contains("note") || h.contains("nota") || h.contains("memo") ||
           h.contains("description") || h.contains("desc") || h.contains("detalle") ||
           h.contains("concepto") {
            return .note
        }
        // Account
        if h.contains("account") || h.contains("cuenta") || h == "wallet" || h.contains("tarjeta") {
            return .account
        }
        return .ignore
    }
}

/// Una fila del CSV parseada + lista de issues de validación.
struct ParsedImportRow: Identifiable, Hashable {
    let id = UUID()
    let lineNumber: Int              // 1-indexed, header = 1
    let raw: [String]                // celdas crudas
    let date: Date?
    let type: TxType?
    let amount: Decimal?
    let currency: String?
    let category: String?
    let subcategory: String?
    let note: String?
    let account: String?
    let issues: [String]             // errores de validación

    var isValid: Bool { issues.isEmpty && date != nil && type != nil && amount != nil }
    var isDuplicate: Bool = false    // se marca después en dedupe
}

/// Resultado del parseo completo de un CSV.
struct ParsedImport {
    let headers: [String]
    let mapping: [TxField]           // alineado con headers (una entrada por columna)
    let rows: [ParsedImportRow]
    let delimiter: Character

    var validCount: Int { rows.filter { $0.isValid && !$0.isDuplicate }.count }
    var duplicateCount: Int { rows.filter { $0.isDuplicate }.count }
    var errorCount: Int { rows.filter { !$0.isValid }.count }
}

/// Parser de CSV básico RFC-4180 compliant.
/// - Detecta delimiter (`,` o `;`) heurísticamente.
/// - Respeta `"..."` con escape `""`.
/// - Soporta newlines Unix (`\n`), Windows (`\r\n`) y classic Mac (`\r`).
/// - Strippea BOM si está presente.
enum CSVParser {
    static func parse(_ text: String) -> [[String]] {
        // 1) Stripear BOM.
        var src = text
        if src.hasPrefix("\u{FEFF}") {
            src.removeFirst()
        }
        // 2) Normalizar line endings a \n para simplificar el parseo.
        //    Orden importa: \r\n debe reemplazarse ANTES que \r solo.
        src = src.replacingOccurrences(of: "\r\n", with: "\n")
        src = src.replacingOccurrences(of: "\r", with: "\n")

        let delimiter = detectDelimiter(src)

        // 3) Parser char-by-char que maneja solo `\n` como separador de fila.
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false

        let chars = Array(src)
        var i = 0
        while i < chars.count {
            let c = chars[i]

            if inQuotes {
                if c == "\"" {
                    // `""` escapa una comilla literal.
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case delimiter:
                    current.append(field)
                    field = ""
                case "\n":
                    current.append(field)
                    rows.append(current)
                    current = []
                    field = ""
                default:
                    field.append(c)
                }
            }
            i += 1
        }

        // Flush final si el archivo no termina en newline.
        if !field.isEmpty || !current.isEmpty {
            current.append(field)
            rows.append(current)
        }

        return rows.filter { !$0.allSatisfy(\.isEmpty) }
    }

    /// Detecta si el CSV usa `,` o `;` como delimiter comparando cuántos aparecen
    /// en las primeras 5 líneas. Excels en es-ES/es-AR suelen usar `;`.
    private static func detectDelimiter(_ text: String) -> Character {
        let sample = text.components(separatedBy: "\n").prefix(5).joined(separator: "\n")
        let commas = sample.filter { $0 == "," }.count
        let semicolons = sample.filter { $0 == ";" }.count
        return semicolons > commas ? ";" : ","
    }
}

// MARK: - Importer

enum TransactionCSVImporter {
    /// Parsea el texto crudo de un CSV y produce una lista de filas con
    /// mapping autodetectado. El caller puede luego corregir el mapping y
    /// re-llamar `applyMapping`.
    static func parse(
        text: String,
        existing: [Transaction] = []
    ) -> ParsedImport {
        let matrix = CSVParser.parse(text)
        guard let rawHeaders = matrix.first else {
            return ParsedImport(headers: [], mapping: [], rows: [], delimiter: ",")
        }

        let headers = rawHeaders
        let mapping = headers.map(TxField.guess(from:))

        let dataRows = matrix.dropFirst()
        var rows = dataRows.enumerated().map { (idx, cells) -> ParsedImportRow in
            parseRow(
                lineNumber: idx + 2,   // +2 porque idx es 0-based y la header es la línea 1
                cells: cells,
                headers: headers,
                mapping: mapping
            )
        }

        // Detección de duplicados vs transacciones existentes
        rows = markDuplicates(rows: rows, existing: existing)

        return ParsedImport(
            headers: headers,
            mapping: mapping,
            rows: rows,
            delimiter: ","
        )
    }

    /// Re-aplicar un mapping modificado por el usuario a un parse previo.
    static func applyMapping(
        _ mapping: [TxField],
        to parsed: ParsedImport,
        text: String,
        existing: [Transaction] = []
    ) -> ParsedImport {
        let matrix = CSVParser.parse(text)
        guard let rawHeaders = matrix.first else { return parsed }
        let dataRows = matrix.dropFirst()
        var rows = dataRows.enumerated().map { (idx, cells) -> ParsedImportRow in
            parseRow(
                lineNumber: idx + 2,
                cells: cells,
                headers: rawHeaders,
                mapping: mapping
            )
        }
        rows = markDuplicates(rows: rows, existing: existing)
        return ParsedImport(
            headers: parsed.headers,
            mapping: mapping,
            rows: rows,
            delimiter: parsed.delimiter
        )
    }

    // MARK: - Row parsing

    private static func parseRow(
        lineNumber: Int,
        cells: [String],
        headers: [String],
        mapping: [TxField]
    ) -> ParsedImportRow {
        // Helper: obtener valor por field
        func value(for field: TxField) -> String? {
            guard let idx = mapping.firstIndex(of: field) else { return nil }
            guard idx < cells.count else { return nil }
            let v = cells[idx].trimmingCharacters(in: .whitespaces)
            return v.isEmpty ? nil : v
        }

        var issues: [String] = []

        // Date
        let dateRaw = value(for: .date)
        let date = dateRaw.flatMap(parseDate)
        if date == nil {
            issues.append("Fecha inválida: '\(dateRaw ?? "")'")
        }

        // Amount + Type
        var amount: Decimal?
        var type: TxType?

        if let signedStr = value(for: .signedAmount) {
            let signed = Money.parse(signedStr) ?? 0
            amount = signed < 0 ? -signed : signed
            type = signed < 0 ? .gasto : .ingreso
        } else {
            if let amountStr = value(for: .amount) {
                amount = Money.parse(amountStr).map { $0 < 0 ? -$0 : $0 }
                if amount == nil {
                    issues.append("Monto inválido: '\(amountStr)'")
                }
            } else {
                issues.append("Falta columna monto")
            }
            if let typeStr = value(for: .type) {
                type = parseType(typeStr)
                if type == nil {
                    issues.append("Tipo no reconocido: '\(typeStr)'")
                }
            } else {
                // Default gasto si no hay type especificado
                type = .gasto
            }
        }

        return ParsedImportRow(
            lineNumber: lineNumber,
            raw: cells,
            date: date,
            type: type,
            amount: amount,
            currency: value(for: .currency)?.uppercased(),
            category: value(for: .category) ?? "Otros",
            subcategory: value(for: .subcategory),
            note: value(for: .note),
            account: value(for: .account),
            issues: issues
        )
    }

    /// Parser tolerante de fechas: ISO 8601, formatos comunes LATAM y US.
    private static func parseDate(_ s: String) -> Date? {
        let isoF = ISO8601DateFormatter()
        isoF.formatOptions = [.withFullDate]
        if let d = isoF.date(from: s) { return d }

        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "d/M/yyyy",
            "d MMM yyyy",
            "dd MMM yyyy",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        ]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for fmt in formats {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    private static func parseType(_ s: String) -> TxType? {
        let lower = s.lowercased()
        if ["expense", "gasto", "debito", "débito", "debit", "salida", "-"].contains(lower) {
            return .gasto
        }
        if ["income", "ingreso", "credito", "crédito", "credit", "entrada", "+"].contains(lower) {
            return .ingreso
        }
        return nil
    }

    /// Marca filas que ya existen en la base (por (fecha, amount, category, note)).
    /// Convención laxa pero efectiva: si hay otra tx el MISMO día con el MISMO
    /// monto y la MISMA categoría y la MISMA nota, consideramos que es la misma.
    ///
    /// **Importante**: para el amount normalizamos a 2 decimales. `"\(Decimal)"`
    /// produce "25000" para algunos decimals y "25000.00" para otros según
    /// cómo se construyeron — inconsistente. Usamos `NSDecimalNumber.string(using:)`
    /// con formatter en_US_POSIX para garantizar matching estable.
    private static func markDuplicates(
        rows: [ParsedImportRow],
        existing: [Transaction]
    ) -> [ParsedImportRow] {
        guard !existing.isEmpty else { return rows }

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? .gmt

        let amountFormatter: NumberFormatter = {
            let f = NumberFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.numberStyle = .decimal
            f.usesGroupingSeparator = false
            f.decimalSeparator = "."
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            return f
        }()

        func key(day: TimeInterval, amount: Decimal, category: String, note: String?) -> String {
            let amt = amountFormatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
            let cat = category.lowercased().trimmingCharacters(in: .whitespaces)
            let n = (note ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            return "\(day)|\(amt)|\(cat)|\(n)"
        }

        let existingKeys: Set<String> = Set(existing.map { tx in
            let day = utcCal.startOfDay(for: tx.date).timeIntervalSince1970
            return key(day: day, amount: tx.amount, category: tx.category, note: tx.note)
        })

        return rows.map { row in
            guard let d = row.date, let a = row.amount else { return row }
            let day = utcCal.startOfDay(for: d).timeIntervalSince1970
            let k = key(day: day, amount: a, category: row.category ?? "", note: row.note)
            var r = row
            r.isDuplicate = existingKeys.contains(k)
            return r
        }
    }

    /// Convierte filas válidas (no duplicadas) en `NewTransactionInput` listos
    /// para mandar al `TransactionService`.
    static func buildInputs(
        from parsed: ParsedImport,
        householdId: UUID,
        userId: UUID,
        defaultCurrency: String
    ) -> [NewTransactionInput] {
        buildInputs(from: parsed, householdId: householdId, userId: userId, defaultCurrency: defaultCurrency, forceImportDuplicates: [])
    }

    /// Overload que permite forzar import de ciertos duplicados (Set de IDs).
    static func buildInputs(
        from parsed: ParsedImport,
        householdId: UUID,
        userId: UUID,
        defaultCurrency: String,
        forceImportDuplicates: Set<UUID>
    ) -> [NewTransactionInput] {
        parsed.rows.compactMap { row -> NewTransactionInput? in
            guard row.isValid else { return nil }
            if row.isDuplicate && !forceImportDuplicates.contains(row.id) { return nil }
            guard let date = row.date, let type = row.type, let amount = row.amount else { return nil }
            return NewTransactionInput(
                householdId: householdId,
                userId: userId,
                accountId: nil,
                type: type,
                amount: amount,
                currencyOriginal: row.currency ?? defaultCurrency,
                category: row.category ?? "Otros",
                subcategory: row.subcategory,
                note: row.note,
                date: date
            )
        }
    }
}
