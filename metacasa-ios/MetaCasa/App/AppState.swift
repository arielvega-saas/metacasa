import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    // Auth
    var session: AuthSession?
    var currentUserId: UUID? { session?.userId }

    // Household
    var currentHouseholdId: UUID?
    var households: [Household] = []

    // UI state
    var isBootstrapping = true
    var lastError: String?

    /// Token del último link de auth ya procesado, para no re-verificar el mismo
    /// `token_hash` dos veces (puede llegar por `.onOpenURL` y por
    /// `.onContinueUserActivity` casi simultáneamente). Un `token_hash` es de un
    /// solo uso: el segundo intento fallaría y pintaría un error falso.
    private var lastHandledTokenHash: String?

    /// Llamado al abrir la app. Intenta restaurar la sesión y, si existe,
    /// marca la app como bloqueada para que `RootView` muestre `LockView`.
    ///
    /// El pedido de biometría legacy que vivía acá se ELIMINÓ: era decorativo
    /// (si fallaba, la app abría igual y nadie chequeaba `isBiometricLocked`).
    /// Ahora `BiometricLockManager.lockOnLaunch()` solo marca el estado y
    /// `LockView` (renderizada por `RootView` en vez del árbol de la app) es
    /// quien dispara la evaluación real con fallback a passcode.
    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        do {
            session = try await AuthManager.shared.restoreSession()
            await TokenHolder.shared.set(session?.accessToken)
            if session != nil {
                BiometricLockManager.shared.lockOnLaunch()
                try await loadHouseholds()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadHouseholds() async throws {
        households = try await HouseholdService.shared.fetchMine()
        if currentHouseholdId == nil || !households.contains(where: { $0.id == currentHouseholdId }) {
            currentHouseholdId = households.first?.id
        }
    }

    func signIn(email: String, password: String) async throws {
        session = try await AuthManager.shared.signIn(email: email, password: password)
        await TokenHolder.shared.set(session?.accessToken)
        try await loadHouseholds()
    }

    func signUp(email: String, password: String) async throws {
        session = try await AuthManager.shared.signUp(email: email, password: password)
        await TokenHolder.shared.set(session?.accessToken)
        try await loadHouseholds()
    }

    /// Procesa un Universal Link de confirmación de email
    /// (`https://usehomefinance.com/auth/confirm?token_hash=...&type=...`).
    /// Verifica el OTP, setea la sesión y carga los hogares — mismo camino que
    /// `signIn`/`signUp`, así el `RootView` reacciona y entra a la app logueado.
    /// Devuelve `true` si manejó el link.
    @discardableResult
    func handleAuthDeepLink(_ url: URL) async -> Bool {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.path == "/auth/confirm",
              let items = comps.queryItems,
              let tokenHash = items.first(where: { $0.name == "token_hash" })?.value,
              let typeRaw = items.first(where: { $0.name == "type" })?.value
        else { return false }

        // Dedup: el mismo link puede entrar por dos callbacks casi a la vez.
        guard tokenHash != lastHandledTokenHash else { return true }
        lastHandledTokenHash = tokenHash

        do {
            session = try await AuthManager.shared.verifyEmailOTP(tokenHash: tokenHash, typeRaw: typeRaw)
            await TokenHolder.shared.set(session?.accessToken)
            try await loadHouseholds()
            return true
        } catch {
            lastError = error.localizedDescription
            lastHandledTokenHash = nil // permití reintentar si falló
            return false
        }
    }

    func signOut() async {
        await AuthManager.shared.signOut()
        await TokenHolder.shared.set(nil)
        session = nil
        currentHouseholdId = nil
        households = []
        BiometricLockManager.shared.resetLock()
        // Limpiamos el índice de Spotlight para que no queden items de la
        // cuenta previa visibles en la búsqueda del sistema, y los snapshots
        // del Home para no dejar data financiera de la cuenta anterior en disco.
        await SpotlightIndexer.deleteAll()
        await HomeSnapshotStore.shared.clearAll()
        // Ídem para el cache offline (SwiftData): entidades de la cuenta
        // anterior no pueden sobrevivir al logout.
        await OfflineCache.shared.clearAll()
        OfflineStatus.shared.reset()
    }

    /// Elimina la cuenta del usuario actual de forma permanente. Apple
    /// Guideline 5.1.1(v): apps con signup deben ofrecer delete in-app.
    /// Tras éxito, limpia estado local y queda en pantalla de login.
    func deleteAccount() async throws {
        try await AccountDeletionService.deleteCurrentUser()
        // El JWT ya no es válido server-side; limpiamos local sin llamar
        // a /logout (que devolvería 401).
        await TokenHolder.shared.set(nil)
        session = nil
        currentHouseholdId = nil
        households = []
        BiometricLockManager.shared.resetLock()
        await SpotlightIndexer.deleteAll()
        await HomeSnapshotStore.shared.clearAll()
        await OfflineCache.shared.clearAll()
        OfflineStatus.shared.reset()
    }

    func switchHousehold(to id: UUID) {
        guard households.contains(where: { $0.id == id }) else { return }
        currentHouseholdId = id
        // El aviso de "datos cacheados" era del hogar anterior; el nuevo se
        // recalcula con el primer load.
        OfflineStatus.shared.reset()
    }
}
