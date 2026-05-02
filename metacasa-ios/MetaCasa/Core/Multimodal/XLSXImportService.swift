import Foundation
import CoreXLSX

/// Parser de archivos XLSX on-device vía CoreXLSX.
/// Convierte la primera hoja del workbook a matriz `[[String]]` (rows x cols)
/// que puede feed-ear al `TransactionCSVImporter` existente.
///
/// Ejemplo de uso:
/// ```swift
/// let rows = try XLSXImportService.readRows(from: url)
/// let csv = XLSXImportService.toCSV(rows: rows)
/// let parsed = TransactionCSVImporter.parse(text: csv, existing: existing)
/// ```
enum XLSXImportService {
    enum XLSXError: LocalizedError {
        case invalidFile
        case noWorksheet
        case readFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidFile: "El archivo XLSX está corrupto o vacío."
            case .noWorksheet: "El archivo no contiene hojas de cálculo."
            case .readFailed(let msg): "Error leyendo XLSX: \(msg)"
            }
        }
    }

    /// Extrae todas las filas de la primera worksheet. Cada row es un array
    /// de strings (los que estén vacíos quedan como "").
    static func readRows(from url: URL) throws -> [[String]] {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let file = XLSXFile(filepath: url.path) else {
            throw XLSXError.invalidFile
        }

        do {
            let sharedStrings = try file.parseSharedStrings()
            guard let firstPath = try file.parseWorksheetPaths().first else {
                throw XLSXError.noWorksheet
            }
            let worksheet = try file.parseWorksheet(at: firstPath)

            guard let sheetData = worksheet.data else {
                return []
            }

            var result: [[String]] = []
            for row in sheetData.rows {
                var cells: [String] = []
                for cell in row.cells {
                    if let shared = sharedStrings,
                       let value = cell.stringValue(shared) {
                        cells.append(value)
                    } else if let inline = cell.inlineString?.text {
                        cells.append(inline)
                    } else {
                        cells.append(cell.value ?? "")
                    }
                }
                result.append(cells)
            }
            return result
        } catch {
            throw XLSXError.readFailed(error.localizedDescription)
        }
    }

    /// Convierte las filas a un CSV RFC 4180 (separador `,`, quotes on fields
    /// que contienen coma/comillas/newline). Comaptible con el parser existente
    /// `TransactionCSVImporter`.
    static func toCSV(rows: [[String]]) -> String {
        rows
            .map { row in row.map(escapeField).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private static func escapeField(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return s
    }
}
