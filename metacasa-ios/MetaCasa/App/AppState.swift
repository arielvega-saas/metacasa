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
    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        do {
            session = try await AuthManager.shared.restoreSession()
            if session != nil {
                // Biometría obligatoria para abrir la app con sesión activa.
                if BiometricAuth.isAvailable {
                    isBiometricLocked = true
                    let ok = (try? await BiometricAuth.authenticate()) ?? false
                    isBiometricLocked = !ok
                    if !ok {
                        // Si falla la biometría, forzamos logout.
                        await signOut()
                        return
                    }
                }
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
        try await loadHouseholds()
    }

    func signUp(email: String, password: String) async throws {
        session = try await AuthManager.shared.signUp(email: email, password: password)
        try await loadHouseholds()
    }

    func signOut() async {
        await AuthManager.shared.signOut()
        session = nil
        currentHouseholdId = nil
        households = []
    }

    func switchHousehold(to id: UUID) {
        guard households.contains(where: { $0.id == id }) else { return }
        currentHouseholdId = id
    }
}
