import SwiftUI

/// Helper centralizado de haptic feedback. Usa la API declarativa
/// `.sensoryFeedback` de SwiftUI (iOS 17+) cuando se aplica a views, y
/// `UINotificationFeedbackGenerator` imperativo cuando lo dispara un action
/// handler directamente.
///
/// Convenciones:
/// - `.success` → confirmar una acción (guardar tx, completar meta, backup OK)
/// - `.warning` → estado ambiguo (over-budget, meta casi vencida)
/// - `.error` → acción falló (crear tx con monto inválido, delete rechazado)
/// - `.selection` → elegir algo (cambiar tab, seleccionar categoría)
/// - `.impact(.light/.medium/.heavy)` → tap en botón importante, deletes
enum Haptics {
    enum Kind: Sendable {
        case success
        case warning
        case error
        case selection
        case impactLight
        case impactMedium
        case impactHeavy
    }

    /// Dispara el feedback. Seguro de llamar desde cualquier hilo —
    /// el generator se crea y prepare+trigger en main queue.
    @MainActor
    static func play(_ kind: Kind) {
        switch kind {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .impactLight:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .impactMedium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .impactHeavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}
