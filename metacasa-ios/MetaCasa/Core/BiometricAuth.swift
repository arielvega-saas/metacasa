import Foundation
import LocalAuthentication

/// Wrapper sobre LocalAuthentication. Nunca bloquea el hilo main.
enum BiometricAuth {
    static var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    static var biometryType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    /// Nombre humano de la biometría disponible ("Face ID", "Touch ID", etc).
    static var biometryLabel: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometría"
        }
    }

    /// Pide biometría al usuario. Retorna true si pasó, false si canceló.
    /// Lanza LAError en casos de error duro (lockout, no enrollment, etc).
    @MainActor
    static func authenticate(reason: String = "Confirmá tu identidad para abrir la app") async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Usar código del dispositivo"

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return false
            default:
                throw error
            }
        }
    }
}
