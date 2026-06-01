import Foundation

/// Handoff de sesión iOS → web.
///
/// Permite que el usuario, ya logueado en la app nativa, abra la versión web de
/// Home Finance **sin tener que re-loguearse**. El flow:
///
///   1. La app invoca la Edge Function `web-handoff` (verify_jwt=true) con el JWT
///      del usuario actual en el header `Authorization: Bearer <token>`.
///   2. La función genera un magic link de un solo uso y devuelve
///      `{ "url": String, "token_hash": String, "type": "magiclink" }`.
///   3. La app abre `response.url` en el navegador del sistema. La web canjea el
///      `token_hash` y queda con sesión iniciada.
///
/// El patrón de red calca exactamente el de `AccountDeletionService` /
/// `CloudTTSService` / `AnthropicProvider`: `URLRequest` directo contra
/// `Config.supabaseURL/functions/v1/<fn>` con headers `Authorization: Bearer` +
/// `apikey`. No usamos `client.functions.invoke` porque el resto del codebase
/// inyecta el token a mano (supabase-swift v2 tiene issues propagando la session
/// al cliente — ver nota en `AuthSession`).
///
/// Cambio aditivo y de bajo riesgo: no toca auth, paywall ni RPC existentes.
enum WebHandoffService {

    // MARK: - Errores

    enum HandoffError: LocalizedError {
        /// No hay un access token vigente (sesión perdida → re-login).
        case noSession
        /// La respuesta no era un HTTP response válido.
        case invalidResponse
        /// La Edge Function devolvió un status != 200.
        case serverError(status: Int, message: String)
        /// El JSON vino sin `url` o con una `url` no parseable.
        case malformedPayload

        var errorDescription: String? {
            switch self {
            case .noSession:
                return String(localized: "webHandoff.error.noSession",
                              defaultValue: "Necesitás tener la sesión iniciada para abrir la versión web.")
            case .invalidResponse, .malformedPayload:
                return String(localized: "webHandoff.error.generic",
                              defaultValue: "No pudimos preparar el acceso web. Probá de nuevo en un momento.")
            case .serverError:
                // No exponemos el status/detalle crudo al usuario (puede traer
                // info del backend). Mensaje genérico; el detalle queda en el throw
                // para debugging si algún día se loguea (sin tokens, claro).
                return String(localized: "webHandoff.error.generic",
                              defaultValue: "No pudimos preparar el acceso web. Probá de nuevo en un momento.")
            }
        }
    }

    // MARK: - API pública

    /// Invoca `web-handoff` y devuelve la URL lista para abrir en el navegador.
    ///
    /// supabase-swift no se usa acá a propósito: replicamos el patrón manual de
    /// `URLRequest` del resto de los servicios para mantener consistencia y
    /// porque el JWT vivo lo tenemos en `TokenHolder`. Antes de leerlo pedimos un
    /// refresh transparente vía `AuthManager.ensureFreshToken()` para no mandar un
    /// access token vencido (la app puede llevar > 1 h abierta).
    ///
    /// - Returns: la `URL` de magic link a abrir.
    /// - Throws: `HandoffError` con mensaje localizado y apto para mostrar.
    static func openWebURL() async throws -> URL {
        // 1. Asegurar un token vigente (auto-refresh si está por expirar).
        //    `ensureFreshToken()` además deja el token fresco en `TokenHolder`.
        let token = await AuthManager.shared.ensureFreshToken()
            ?? (await TokenHolder.shared.get())
        guard let token, !token.isEmpty else {
            throw HandoffError.noSession
        }

        // 2. Armar el request a la Edge Function (mismo patrón que delete-account).
        let url = Config.supabaseURL.appendingPathComponent("functions/v1/web-handoff")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.timeoutInterval = 30

        // 3. Ejecutar.
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw HandoffError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let msg = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
                ?? String(data: data, encoding: .utf8)
                ?? "(sin detalle)"
            throw HandoffError.serverError(status: http.statusCode, message: msg)
        }

        // 4. Decodificar { url, token_hash, type } — solo necesitamos `url`.
        guard let payload = try? JSONDecoder().decode(HandoffResponse.self, from: data),
              let parsed = URL(string: payload.url) else {
            throw HandoffError.malformedPayload
        }
        return parsed
    }

    /// URL de fallback cuando el handoff falla: abre el login de la web a secas.
    /// El usuario tendrá que loguearse a mano, pero al menos llega a la web.
    static var fallbackLoginURL: URL? {
        URL(string: Config.webAppURL.absoluteString + "/login")
    }

    // MARK: - DTOs

    /// Respuesta esperada de `web-handoff`. Solo `url` es load-bearing del lado
    /// app; `token_hash`/`type` se decodifican para validar el contrato pero la
    /// web es quien canjea el `token_hash`.
    private struct HandoffResponse: Decodable {
        let url: String
        let tokenHash: String?
        let type: String?

        enum CodingKeys: String, CodingKey {
            case url
            case tokenHash = "token_hash"
            case type
        }
    }

    private struct ErrorBody: Decodable { let error: String }
}
