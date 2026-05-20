import Foundation

/// Borra la cuenta del usuario actual llamando a la Edge Function
/// `delete-account` (que invoca `auth.admin.deleteUser` con service_role).
///
/// Requerido por App Store Review Guideline 5.1.1(v) para apps con creación
/// de cuenta. El flow del lado iOS: confirmación doble → llamada de red →
/// signOut local + limpieza de session.
enum AccountDeletionService {
    enum DeletionError: LocalizedError {
        case noSession
        case invalidResponse
        case serverError(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .noSession:
                return "No hay una sesión activa para borrar."
            case .invalidResponse:
                return "Respuesta inesperada del servidor."
            case .serverError(let status, let msg):
                return "El servidor rechazó la solicitud (\(status)): \(msg)"
            }
        }
    }

    /// Borra la cuenta del usuario autenticado. Tras éxito, el JWT del cliente
    /// queda inválido y cualquier request siguiente devolverá 401. El llamador
    /// debe ejecutar `signOut()` para limpiar el estado local.
    static func deleteCurrentUser() async throws {
        guard let token = await TokenHolder.shared.get() else {
            throw DeletionError.noSession
        }

        let url = Config.supabaseURL.appendingPathComponent("functions/v1/delete-account")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw DeletionError.invalidResponse
        }
        if http.statusCode == 200 { return }

        let msg = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            ?? String(data: data, encoding: .utf8)
            ?? "(sin detalle)"
        throw DeletionError.serverError(status: http.statusCode, message: msg)
    }

    private struct ErrorBody: Decodable { let error: String }
}
