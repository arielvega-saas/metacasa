import Foundation

/// Rango de fechas para filtrar el export.
enum ExportDateRange: Hashable, Identifiable {
    case currentMonth
    case lastMonth
    case last30Days
    case last90Days
    case ytd
    case allTime
    case custom(from: Date, to: Date)

    var id: String {
        switch self {
        case .currentMonth: return "currentMonth"
        case .lastMonth:    return "lastMonth"
        case .last30Days:   return "last30Days"
        case .last90Days:   return "last90Days"
        case .ytd:          return "ytd"
        case .allTime:      return "allTime"
        case .custom:       return "custom"
        }
    }

    /// Convertir a tupla concreta (from, to) para filtrar transacciones.
    /// `allTime` usa un rango gigante (distant past → now) para que sirva con
    /// las queries existentes que exigen fechas.
    func resolved(now: Date = Date(), calendar: Calendar = .current) -> (from: Date, to: Date) {
        switch self {
        case .currentMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: comps) ?? now
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59, second: 59), to: start) ?? now
            return (start, end)

        case .lastMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let thisStart = calendar.date(from: comps) ?? now
            let start = calendar.date(byAdding: .month, value: -1, to: thisStart) ?? now
            let end = calendar.date(byAdding: DateComponents(second: -1), to: thisStart) ?? now
            return (start, end)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)

        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return (start, now)

        case .ytd:
            let comps = calendar.dateComponents([.year], from: now)
            let start = calendar.date(from: comps) ?? now
            return (start, now)

        case .allTime:
            return (Date(timeIntervalSince1970: 0), now)

        case .custom(let from, let to):
            return (from, to)
        }
    }
}

/// Formato de archivo exportado.
enum ExportFormat: String, CaseIterable, Identifiable {
    case csv
    case pdf

    var id: String { rawValue }
    var fileExtension: String { rawValue }
    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .pdf: return "application/pdf"
        }
    }
}

/// Documento listo para compartir via Share Sheet.
/// Se escribe a un archivo temporal con un nombre descriptivo; `ShareLink`
/// toma la URL y presenta el Share Sheet nativo (AirDrop, Mail, Drive, etc).
struct ExportedDocument: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let format: ExportFormat
    let fileName: String
    let byteCount: Int
}
