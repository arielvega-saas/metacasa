import Foundation
import Supabase

struct AuthSession: Sendable, Hashable {
    let userId: UUID
    let email: String?
    let expiresAt: Date?
    /// Guardado en memoria porque supabase-swift v2 tiene issues propagando
    /// la session al PostgREST client. Lo inyectamos manualmente en cada request.
    let accessToken: String
    let refreshToken: String
}

enum AuthError: LocalizedError {
    case emailConfirmationPending
    case sessionMissing

    var errorDescription: String? {
        switch self {
        case .emailConfirmationPending:
            return "Confirmá tu email antes de entrar. Revisá tu bandeja (y spam)."
        case .sessionMissing:
            return "Sesión no disponible. Volvé a iniciar sesión."
        }
    }
}

@MainActor
final class AuthManager {
    static let shared = AuthManager()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    /// Intenta restaurar la sesión guardada. Devuelve nil si no hay o expiró.
    func restoreSession() async throws -> AuthSession? {
        do {
            let session = try await client.auth.session
            return Self.map(session)
        } catch {
            // No session stored or expired
            return nil
        }
    }

    /// Pide a supabase-swift que devuelva una session válida — el accessor
    /// `client.auth.session` ejecuta un refresh transparente si el access token
    /// está expirado o cerca de expirar, usando el refresh_token guardado.
    /// Lanza si el refresh_token también caducó (sesión perdida → forzar relogin).
    func refreshSession() async throws -> AuthSession {
        let session = try await client.auth.session
        return Self.map(session)
    }

    /// Asegura que `TokenHolder` tenga un access_token vigente. supabase-swift
    /// hace auto-refresh con el refresh_token si el access está vencido o
    /// próximo a vencer. Esto es necesario para flows long-running como el
    /// Asistente IA, donde la app puede estar abierta > 1 hora y sin esto
    /// caería con 401 silenciosamente.
    ///
    /// Retorna el token vigente, o `nil` si la sesión está perdida
    /// (refresh_token vencido → user debe re-loguear desde la app).
    @discardableResult
    func ensureFreshToken() async -> String? {
        do {
            let session = try await client.auth.session
            let mapped = Self.map(session)
            await TokenHolder.shared.set(mapped.accessToken)
            return mapped.accessToken
        } catch {
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let session = try await client.auth.signIn(email: email, password: password)
        return Self.map(session)
    }

    /// Retorna la sesión si el signup ya logueó al usuario, o lanza emailConfirmationPending
    /// si el proyecto Supabase requiere confirmación por email antes del primer login.
    func signUp(email: String, password: String) async throws -> AuthSession {
        let response = try await client.auth.signUp(email: email, password: password)
        if let s = response.session {
            return Self.map(s)
        }
        throw AuthError.emailConfirmationPending
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    private static func map(_ session: Session) -> AuthSession {
        AuthSession(
            userId: session.user.id,
            email: session.user.email,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt),
            accessToken: session.accessToken,
            refreshToken: session.refreshToken
        )
    }
}
