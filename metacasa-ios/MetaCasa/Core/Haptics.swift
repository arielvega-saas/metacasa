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

    // Generators estáticos: instanciar uno por llamada agrega latencia
    // perceptible al primer haptic. Mantenerlos vivos y llamar `prepare()`
    // tras cada disparo los deja "calientes" para el próximo tap
    // (recomendación de Apple para feedback de baja latencia).
    @MainActor private static let notificationGen = UINotificationFeedbackGenerator()
    @MainActor private static let selectionGen = UISelectionFeedbackGenerator()
    @MainActor private static let impactLightGen = UIImpactFeedbackGenerator(style: .light)
    @MainActor private static let impactMediumGen = UIImpactFeedbackGenerator(style: .medium)
    @MainActor private static let impactHeavyGen = UIImpactFeedbackGenerator(style: .heavy)

    /// Dispara el feedback. Seguro de llamar desde cualquier hilo —
    /// el generator vive y se dispara en main queue.
    @MainActor
    static func play(_ kind: Kind) {
        switch kind {
        case .success:
            notificationGen.notificationOccurred(.success)
            notificationGen.prepare()
        case .warning:
            notificationGen.notificationOccurred(.warning)
            notificationGen.prepare()
        case .error:
            notificationGen.notificationOccurred(.error)
            notificationGen.prepare()
        case .selection:
            selectionGen.selectionChanged()
            selectionGen.prepare()
        case .impactLight:
            impactLightGen.impactOccurred()
            impactLightGen.prepare()
        case .impactMedium:
            impactMediumGen.impactOccurred()
            impactMediumGen.prepare()
        case .impactHeavy:
            impactHeavyGen.impactOccurred()
            impactHeavyGen.prepare()
        }
    }
}
