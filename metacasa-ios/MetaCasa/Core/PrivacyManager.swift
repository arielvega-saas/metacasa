import Foundation
import Observation

/// Gestor de modo privacidad y consentimientos del usuario.
///
/// Tres flags persistidos:
/// 1. `isEnabled` — modo privacidad de UI (oculta montos con ••••).
/// 2. `assistantCloudConsent` — el user aceptó explícitamente que el
///    Asistente IA pueda enviar consultas a Claude (Anthropic) en la nube.
///    Required por App Store Review Guideline 5.1.1 para apps con AI cloud.
/// 3. `assistantOnDeviceOnly` — el user opta por correr solo on-device
///    (Apple Intelligence FoundationModels). Si está ON, el Tier 2 cloud
///    queda deshabilitado aunque haya consent. Útil para usuarios que
///    quieren garantía absoluta de no salir del dispositivo.
@MainActor
@Observable
final class PrivacyManager {
    static let shared = PrivacyManager()

    private let blurKey = "app_privacy_mode"
    private let consentKey = "app_assistant_cloud_consent"
    private let onDeviceKey = "app_assistant_on_device_only"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: blurKey) }
    }

    /// `true` cuando el user vio y aceptó el AssistantConsentSheet.
    /// `false` por default — el chat muestra el sheet al primer uso.
    var assistantCloudConsent: Bool {
        didSet { UserDefaults.standard.set(assistantCloudConsent, forKey: consentKey) }
    }

    /// `true` cuando el user fuerza on-device only (degrade calidad pero
    /// garantiza no envío a cloud). Default `false`.
    var assistantOnDeviceOnly: Bool {
        didSet { UserDefaults.standard.set(assistantOnDeviceOnly, forKey: onDeviceKey) }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: blurKey)
        self.assistantCloudConsent = UserDefaults.standard.bool(forKey: consentKey)
        self.assistantOnDeviceOnly = UserDefaults.standard.bool(forKey: onDeviceKey)
    }

    func toggle() { isEnabled.toggle() }

    /// Devuelve `original` si privacy OFF, o un string ofuscado "••••" si privacy ON.
    func obfuscate(_ original: String) -> String {
        isEnabled ? "••••" : original
    }

    /// El chat puede ir al cloud LLM si el user dio consent Y no forzó
    /// on-device only. Si retorna `false`, el asistente cae al Tier 1
    /// (FoundationModels) o al Tier 3 (statistical fallback).
    var canUseCloudAssistant: Bool {
        assistantCloudConsent && !assistantOnDeviceOnly
    }
}
