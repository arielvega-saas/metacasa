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
    var isBiometricLocked = false
    var lastError: String?

    /// Llamado al abrir la app. Intenta restaurar la sesión y, si existe,
    /// pide biometría antes de exponer la UI con datos.
    /// En simulator se saltea biometría (no hay Face ID real).
    /// En device real, si la biometría falla (cancela, no enrollada), NO forzamos
    /// logout: mantenemos la sesión y dejamos que la app abra. Si el usuario quiere
    /// re-bloquear con biometría, lo puede activar desde Ajustes (pendiente).
    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        do {
            session = try await AuthManager.shared.restoreSession()
            await TokenHolder.shared.set(session?.accessToken)
            if session != nil {
                #if !targetEnvironment(simulator)
                if BiometricAuth.isAvailable {
                    isBiometricLocked = true
                    let ok = (try? await BiometricAuth.authenticate()) ?? false
                    isBiometricLocked = !ok
                    // Si falla, solo logueamos advertencia — no forzamos signOut.
                    if !ok {
                        lastError = "Biometría no verificada. Tu sesión sigue activa."
                    }
                }
                #endif
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

    func signOut() async {
        await AuthManager.shared.signOut()
        await TokenHolder.shared.set(nil)
        session = nil
        currentHouseholdId = nil
        households = []
        // Limpiamos el índice de Spotlight para que no queden items de la
        // cuenta previa visibles en la búsqueda del sistema.
        await SpotlightIndexer.deleteAll()
    }

    func switchHousehold(to id: UUID) {
        guard households.contains(where: { $0.id == id }) else { return }
        currentHouseholdId = id
    }
}
