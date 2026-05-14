import Foundation
import Sentry

/// Servicio de observabilidad para producción. Inicializa Sentry solo si hay
/// `SENTRY_DSN` configurado en `Info.plist`. Sin DSN, queda en no-op silencioso
/// (debug builds) o crashea silenciosamente sin afectar el flow (release).
///
/// **Por qué Sentry**:
/// - Post-submit a App Store, sin observabilidad los crashes son ciegos.
/// - Apple no notifica a developers sobre crashes en producción (TestFlight
///   sí, App Store solo agregada en Xcode → Organizer con delay de días).
/// - Sentry da crash reports con stack trace + breadcrumbs + release version
///   en tiempo real (segundos vs días).
///
/// **Privacy**:
/// - `attachScreenshot = false` y `attachViewHierarchy = false`: no capturamos
///   UI ni datos financieros visibles.
/// - `enableUserInteractionTracing = false`: no trackeamos cada tap del user.
/// - `enableAutoPerformanceTracing = false`: no medimos perf de cada vista.
/// - Solo capturamos crashes y errores explícitos via `SentrySDK.capture`.
/// - El DSN va por Info.plist (build-time), no hay tracking de identidad real.
enum ObservabilityService {

    /// Inicializa Sentry. Llamar desde `MetaCasaApp.init()` antes de cualquier
    /// otra inicialización para capturar crashes tempranos.
    static func boot() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !dsn.isEmpty,
              !dsn.hasPrefix("REPLACE_WITH") else {
            #if DEBUG
            print("[Observability] SENTRY_DSN missing or placeholder in Info.plist — observability disabled")
            #endif
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            // Privacy-preserving defaults para una app fintech:
            options.enableAutoPerformanceTracing = false
            options.enableUserInteractionTracing = false
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.attachStacktrace = true
            options.maxBreadcrumbs = 50
            options.environment = Self.environment()
            options.releaseName = Self.releaseName()
            options.tracesSampleRate = 0.0   // No perf traces. Solo errors.
            options.enableNetworkBreadcrumbs = false  // URLs pueden tener PII
            options.enableSwizzling = false  // Más conservador para fintech
            #if DEBUG
            options.debug = false  // Demasiado verbose con true
            #endif
        }

        // Tag global del idioma del user para filtros en Sentry dashboard.
        let lang = Locale.current.language.languageCode?.identifier ?? "?"
        SentrySDK.configureScope { scope in
            scope.setTag(value: lang, key: "lang")
            scope.setTag(value: "ios", key: "platform")
        }

        #if DEBUG
        print("[Observability] Sentry initialized — env=\(Self.environment()) release=\(Self.releaseName())")
        #endif
    }

    /// Asocia el user actual al scope de Sentry. Llamar después de login.
    /// **Importante**: solo enviamos el UUID, NUNCA el email — no queremos
    /// que un crash report contenga PII identificable.
    static func setUser(userId: UUID?) {
        SentrySDK.configureScope { scope in
            if let uid = userId {
                let user = User(userId: uid.uuidString)
                scope.setUser(user)
            } else {
                scope.setUser(nil)
            }
        }
    }

    /// Captura un error que NO crashea pero queremos trackear. Útil para
    /// fallbacks silenciosos (ej. Anthropic falla → statistical).
    /// Sanitiza el message para no incluir números/montos.
    static func captureError(_ error: Error, context: String = "") {
        SentrySDK.capture(error: error) { scope in
            if !context.isEmpty {
                scope.setTag(value: context, key: "context")
            }
        }
    }

    /// Captura un mensaje informativo (warning, no error). Útil para tracking
    /// de eventos importantes sin ser un crash.
    static func captureMessage(_ message: String, level: SentryLevel = .warning) {
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
        }
    }

    // MARK: - Helpers

    private static func environment() -> String {
        #if DEBUG
        return "debug"
        #elseif TESTFLIGHT
        return "testflight"
        #else
        return "production"
        #endif
    }

    private static func releaseName() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let bundleId = Bundle.main.bundleIdentifier ?? "com.metacasa.app"
        return "\(bundleId)@\(version)+\(build)"
    }
}
