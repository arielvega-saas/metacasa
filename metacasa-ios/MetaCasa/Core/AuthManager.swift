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
    /// `redirectTo` apunta al dominio propio (`usehomefinance.com/auth/confirm`),
    /// que la app reclama como Universal Link: al tocar el link del mail, iOS abre
    /// la app y completamos la confirmación con `verifyEmailOTP`. Si la app no está
    /// instalada, el mismo link cae a la web. Pasarlo explícito hace que el flow no
    /// dependa del campo "Site URL" del dashboard de Supabase.
    func signUp(email: String, password: String) async throws -> AuthSession {
        let redirect = URL(string: "https://usehomefinance.com/auth/confirm?next=/dashboard")
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: redirect
        )
        if let s = response.session {
            return Self.map(s)
        }
        throw AuthError.emailConfirmationPending
    }

    /// Completa la confirmación de un link de email (signup / magic link / cambio
    /// de email) a partir del `token_hash` que viaja en el Universal Link
    /// `https://usehomefinance.com/auth/confirm?token_hash=...&type=...`.
    /// Usa el flujo cross-device de Supabase (no depende de `code_verifier`): el
    /// mismo link funciona aunque el mail se abra en otro dispositivo.
    /// `typeRaw` es el query param `type`, que mapea 1:1 al rawValue de
    /// `EmailOTPType` ("signup", "magiclink", "email_change", ...).
    func verifyEmailOTP(tokenHash: String, typeRaw: String) async throws -> AuthSession {
        guard let type = EmailOTPType(rawValue: typeRaw) else {
            throw AuthError.sessionMissing
        }
        let response = try await client.auth.verifyOTP(tokenHash: tokenHash, type: type)
        guard let session = response.session else {
            throw AuthError.sessionMissing
        }
        return Self.map(session)
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
