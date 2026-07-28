import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Attributes del Live Activity del próximo vencimiento. `billId` es fijo para
/// la activity (attribute estático); el contenido dinámico (title, amount,
/// dueDate) va en `ContentState`.
///
/// **Este archivo se compila en AMBOS targets** (app + `MetaCasaWidgets`) —
/// ver `sources` en `project.yml`. ActivityKit matchea la activity con su UI
/// por identidad de tipo: si la app usara un `BillReminderAttributes` propio y
/// la extension otro, la Live Activity arrancaría sin UI. Por eso vive acá y
/// no dentro de `LiveActivityService`.
@available(iOS 16.1, *)
struct BillReminderAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var amount: Decimal
        var currency: String
        var dueDate: Date

        /// Formatted amount — para render en el Widget.
        var formattedAmount: String {
            let nf = NumberFormatter()
            nf.numberStyle = .currency
            nf.currencyCode = currency
            nf.maximumFractionDigits = 0
            return nf.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        }

        /// Horas restantes hasta el vencimiento. Negativo si ya pasó.
        var hoursUntilDue: Int {
            Int(dueDate.timeIntervalSinceNow / 3600)
        }
    }

    /// ID del bill. Identifica la activity de manera única; permite update
    /// sin crear otra duplicada.
    var billId: String
}
#endif
