import Foundation
import Observation
import LocalAuthentication

/// Face ID lock REAL de la app (ítem 3.2 del plan de mejoras).
///
/// Antes el pedido de biometría del bootstrap era decorativo: si fallaba, la
/// app abría igual y `RootView` nunca chequeaba el estado. Ahora el flujo es:
/// - `AppState.bootstrap()` llama `lockOnLaunch()` al restaurar sesión.
/// - `RootView` renderiza `LockView` EN VEZ del árbol de la app mientras
///   `isEnabled && isLocked` (los datos ni se construyen).
/// - `LockView` dispara `unlock()` (biometría con fallback a passcode).
/// - Al backgroundear, `RootView` marca `noteBackgrounded()`; al volver a
///   `.active` llama `lockIfNeeded()` — con grace period de 60s para no
///   pedir Face ID en cada switch rápido de app.
@MainActor
@Observable
final class BiometricLockManager {
    static let shared = BiometricLockManager()

    /// Ventana de gracia: si el user vuelve del background en menos de esto,
    /// no re-pedimos autenticación.
    static let gracePeriod: TimeInterval = 60

    private static let enabledKey = "app_biometric_lock_enabled"

    /// Preferencia persistida del usuario. Default en primera ejecución:
    /// `true` si el device soporta biometría — la app ya pedía Face ID al
    /// abrir, esto solo lo hace efectivo (no cambia la expectativa del user).
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    /// `true` mientras la app está bloqueada esperando autenticación.
    private(set) var isLocked = false

    /// Momento en que la app pasó a `.background`. Se compara contra
    /// `gracePeriod` al volver a `.active`.
    var lastBackgroundedAt: Date?

    private init() {
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil {
            isEnabled = BiometricAuth.isAvailable
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        }
    }

    /// Marca la app como bloqueada al arrancar con sesión restaurada.
    /// NO evalúa biometría acá — `LockView` es quien dispara `unlock()`.
    /// En simulator no bloqueamos (QA/screenshots sin Face ID real), igual
    /// que hacía el pedido legacy del bootstrap.
    func lockOnLaunch() {
        #if !targetEnvironment(simulator)
        guard isEnabled, BiometricAuth.isAvailable else { return }
        isLocked = true
        #endif
    }

    /// Llamar cuando la escena pasa a `.background`.
    func noteBackgrounded() {
        lastBackgroundedAt = Date()
    }

    /// Llamar cuando la escena vuelve a `.active`: re-bloquea si el user
    /// estuvo afuera más que el grace period.
    func lockIfNeeded() {
        defer { lastBackgroundedAt = nil }
        guard isEnabled, !isLocked else { return }
        guard let backgroundedAt = lastBackgroundedAt else { return }
        if Date().timeIntervalSince(backgroundedAt) >= Self.gracePeriod {
            isLocked = true
        }
    }

    /// Pide autenticación al sistema (`.deviceOwnerAuthentication` = biometría
    /// CON fallback a passcode — nunca dejamos al user afuera de sus datos).
    /// Devuelve `true` si desbloqueó.
    ///
    /// Fail-open documentado: si el device no puede autenticar de ninguna
    /// forma (sin passcode configurado, biometría rota), desbloqueamos —
    /// preferimos abrir a dejar al dueño afuera; un device sin passcode no
    /// tiene seguridad de OS de todos modos.
    func unlock() async -> Bool {
        guard isLocked else { return true }
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "lock.fallback")
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "lock.reason")
            )
            if ok {
                isLocked = false
                lastBackgroundedAt = nil
            }
            return ok
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                // El user canceló: sigue bloqueada, puede reintentar con el botón.
                return false
            default:
                // Error duro (passcodeNotSet, etc.) → fail-open, ver doc arriba.
                isLocked = false
                return true
            }
        } catch {
            isLocked = false
            return true
        }
    }

    /// Activa el lock desde Ajustes verificando PRIMERO que la autenticación
    /// funciona (evita dejar al user con un lock que no puede pasar).
    /// Devuelve `true` si se verificó y quedó activado.
    func verifyAndEnable() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "lock.fallback")
        let ok = (try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "lock.reason")
        )) ?? false
        if ok {
            isEnabled = true
        }
        return ok
    }

    /// Desactiva el lock (toggle de Ajustes en OFF).
    func disable() {
        isEnabled = false
        isLocked = false
        lastBackgroundedAt = nil
    }

    /// Limpia el estado de bloqueo. Llamado en signOut/deleteAccount para que
    /// el próximo login (que ya autentica con password) no arranque bloqueado.
    func resetLock() {
        isLocked = false
        lastBackgroundedAt = nil
    }
}
