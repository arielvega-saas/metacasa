import Foundation
import PDFKit

/// Extrae texto plano de un PDF de resumen bancario / wallet (MercadoPago,
/// Brubank, Uala, banco tradicional, tarjeta de crédito, etc.).
///
/// **Por qué existe**: el usuario descarga el resumen de su wallet en PDF y
/// quiere que el asistente le cargue los gastos. Antes el asistente solo
/// soportaba CSV/XLS/XLSX. PDF es el formato más común que la gente baja de
/// su home banking.
///
/// Flujo: `PDFStatementService.extractText(from:)` → texto crudo →
/// `AnthropicProvider.parseStatementToCSV(...)` (Claude normaliza a CSV) →
/// `TransactionCSVImporter` (dedup + preview + import inline). Reusa toda la
/// infra de import existente.
///
/// Decisión: NO parseamos el PDF con regex acá. Los formatos de resumen
/// varían muchísimo entre bancos/wallets y entre versiones. Claude es mucho
/// más robusto entendiendo tablas con descripciones multilínea, montos en
/// formato local ($ -4.990,00), y distinguiendo gastos reales de movimientos
/// internos (ej. "Reserva por gastos Ahorro" de MercadoPago NO es un gasto).
enum PDFStatementService {

    enum PDFError: LocalizedError {
        case cannotOpen
        case emptyDocument
        case noTextContent

        var errorDescription: String? {
            switch self {
            case .cannotOpen:
                "No pude abrir el PDF. ¿Está protegido con contraseña?"
            case .emptyDocument:
                "El PDF no tiene páginas."
            case .noTextContent:
                "El PDF no tiene texto seleccionable (parece escaneado como imagen). Probá exportar el resumen en CSV o Excel desde tu banco/wallet."
            }
        }
    }

    /// Extrae todo el texto del PDF, página por página, separado por saltos
    /// de línea. Mantiene el orden de lectura. Si el PDF es un scan (imagen
    /// sin capa de texto), `page.string` viene vacío → lanza `.noTextContent`
    /// para que el caller pueda sugerir CSV o usar el flujo de vision/OCR.
    static func extractText(from url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let doc = PDFDocument(url: url) else {
            throw PDFError.cannotOpen
        }
        guard doc.pageCount > 0 else {
            throw PDFError.emptyDocument
        }

        var chunks: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            if let text = page.string, !text.isEmpty {
                chunks.append(text)
            }
        }

        let full = chunks.joined(separator: "\n")
        guard !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PDFError.noTextContent
        }

        // Cap defensivo: un resumen muy largo (cientos de páginas) podría
        // saturar el context window. 60k chars ≈ ~15k tokens, bien dentro
        // del límite de Haiku. Si excede, truncamos avisando.
        let maxChars = 60_000
        if full.count > maxChars {
            let prefix = String(full.prefix(maxChars))
            return prefix + "\n\n[... resumen truncado: el PDF es muy largo, se procesaron los primeros movimientos ...]"
        }
        return full
    }

    /// `true` si la URL apunta a un PDF (por extensión o UTI).
    static func isPDF(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf"
    }
}
