import Foundation

// MARK: - TokenHolder
/// Guardián del JWT vigente. `AppState` lo setea en signIn/restore/signOut;
/// `SupabaseRPC` lo lee en cada request para inyectarlo como `Authorization: Bearer`.
actor TokenHolder {
    static let shared = TokenHolder()
    private init() {}
    private var accessToken: String?

    func set(_ token: String?) { accessToken = token }
    func get() -> String? { accessToken }
    func require() throws -> String {
        guard let t = accessToken, !t.isEmpty else {
            throw NSError(
                domain: "SupabaseRPC",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Sesión no disponible. Volvé a iniciar sesión."]
            )
        }
        return t
    }
}

// MARK: - PgQuery
/// Builder para query strings PostgREST (`?col=eq.x&order=col.desc&limit=N`).
struct PgQuery {
    private var items: [URLQueryItem] = []

    init(select: String = "*") {
        items.append(URLQueryItem(name: "select", value: select))
    }

    private func adding(_ item: URLQueryItem) -> PgQuery {
        var c = self; c.items.append(item); return c
    }

    func eq(_ column: String, _ value: String) -> PgQuery {
        adding(URLQueryItem(name: column, value: "eq.\(value)"))
    }
    func eq(_ column: String, _ value: UUID) -> PgQuery {
        eq(column, value.uuidString.lowercased())
    }
    func eq(_ column: String, _ value: Bool) -> PgQuery {
        eq(column, value ? "true" : "false")
    }
    func eq(_ column: String, _ value: Int) -> PgQuery {
        eq(column, String(value))
    }
    func neq(_ column: String, _ value: String) -> PgQuery {
        adding(URLQueryItem(name: column, value: "neq.\(value)"))
    }
    func gte(_ column: String, _ value: Date) -> PgQuery {
        adding(URLQueryItem(name: column, value: "gte.\(Self.iso(value))"))
    }
    func lte(_ column: String, _ value: Date) -> PgQuery {
        adding(URLQueryItem(name: column, value: "lte.\(Self.iso(value))"))
    }
    func order(_ column: String, ascending: Bool = true) -> PgQuery {
        adding(URLQueryItem(name: "order", value: "\(column).\(ascending ? "asc" : "desc")"))
    }
    func limit(_ n: Int) -> PgQuery {
        adding(URLQueryItem(name: "limit", value: String(n)))
    }

    var urlItems: [URLQueryItem] { items }

    static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }
}

// MARK: - SupabaseRPC
/// Cliente mínimo para Supabase/PostgREST que **inyecta el JWT manualmente**
/// en cada request. Workaround a un bug de supabase-swift v2 donde la session
/// no se propaga consistentemente al PostgREST client → requests caen como
/// rol `anon` y RLS rechaza.
enum SupabaseRPC {
    // MARK: - Coders
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)

            // Formato Postgres con microsegundos: "2026-04-20 00:50:41.767043+00"
            let pg = DateFormatter()
            pg.locale = Locale(identifier: "en_US_POSIX")
            pg.timeZone = TimeZone(secondsFromGMT: 0)
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                "yyyy-MM-dd HH:mm:ss.SSSSSSXX",
                "yyyy-MM-dd HH:mm:ssXX",
                "yyyy-MM-dd"
            ]
            for fmt in formats {
                pg.dateFormat = fmt
                if let date = pg.date(from: str) { return date }
            }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Formato de fecha no soportado: \(str)"
            )
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - URL builders
    private static func baseURL(path: String, query: [URLQueryItem] = []) -> URL {
        var comps = URLComponents(
            url: Config.supabaseURL
                .appendingPathComponent("rest")
                .appendingPathComponent("v1")
                .appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty {
            comps.queryItems = (comps.queryItems ?? []) + query
        }
        return comps.url!
    }

    // MARK: - Request helper
    private static func perform(
        _ req: inout URLRequest,
        accessToken: String,
        retryOnExpired: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "SupabaseRPC", code: 0, userInfo: [NSLocalizedDescriptionKey: "Respuesta HTTP inválida"])
        }
        // PostgREST devuelve 401 PGRST303 cuando el JWT expiró. Refrescamos una
        // vez con el refresh_token y reintentamos; si también falla, cae al
        // throw normal de abajo.
        if http.statusCode == 401, retryOnExpired {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.contains("PGRST303") || body.contains("JWT expired") {
                let newToken = try await refreshAccessToken()
                return try await perform(&req, accessToken: newToken, retryOnExpired: false)
            }
        }
        if !(200..<300 ~= http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "sin detalle"
            throw NSError(
                domain: "SupabaseRPC",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]
            )
        }
        return (data, http)
    }

    private static func currentToken() async throws -> String {
        try await TokenHolder.shared.require()
    }

    /// Refresca el access_token usando el refresh_token via supabase-swift y
    /// actualiza `TokenHolder`. Si el refresh también falla (refresh_token
    /// caducado o revocado), limpia el TokenHolder y propaga un error legible
    /// para que la UI fuerce relogin.
    private static func refreshAccessToken() async throws -> String {
        do {
            let newSession = try await AuthManager.shared.refreshSession()
            await TokenHolder.shared.set(newSession.accessToken)
            return newSession.accessToken
        } catch {
            await TokenHolder.shared.set(nil)
            throw NSError(
                domain: "SupabaseRPC",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Tu sesión expiró. Volvé a iniciar sesión."]
            )
        }
    }

    // MARK: - RPC
    /// Llama una RPC y decodifica el resultado.
    static func call<Input: Encodable, Output: Decodable>(
        _ functionName: String,
        params: Input
    ) async throws -> Output {
        let token = try await currentToken()
        return try await call(functionName, params: params, accessToken: token)
    }

    /// Variante con accessToken explícito (compat con HouseholdService.create).
    static func call<Input: Encodable, Output: Decodable>(
        _ functionName: String,
        params: Input,
        accessToken: String
    ) async throws -> Output {
        var req = URLRequest(url: baseURL(path: "rpc/\(functionName)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(params)
        let (data, _) = try await perform(&req, accessToken: accessToken)
        return try decoder.decode(Output.self, from: data)
    }

    static func call<Output: Decodable>(_ functionName: String) async throws -> Output {
        try await call(functionName, params: EmptyParams())
    }

    /// RPC sin parsear response (para side-effects / void returns).
    static func callVoid<Input: Encodable>(
        _ functionName: String,
        params: Input
    ) async throws {
        let token = try await currentToken()
        var req = URLRequest(url: baseURL(path: "rpc/\(functionName)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(params)
        _ = try await perform(&req, accessToken: token)
    }

    // MARK: - SELECT
    /// Select multi-row. Devuelve array; vacío si no hay resultados.
    static func select<Output: Decodable>(
        from table: String,
        query: PgQuery = PgQuery()
    ) async throws -> [Output] {
        let token = try await currentToken()
        var req = URLRequest(url: baseURL(path: table, query: query.urlItems))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await perform(&req, accessToken: token)
        return try decoder.decode([Output].self, from: data)
    }

    /// Select de 1 fila como opcional (equivale a `.limit(1).first`).
    static func selectFirst<Output: Decodable>(
        from table: String,
        query: PgQuery = PgQuery()
    ) async throws -> Output? {
        let rows: [Output] = try await select(from: table, query: query.limit(1))
        return rows.first
    }

    // MARK: - INSERT
    /// Insert retornando la fila creada.
    static func insert<Input: Encodable, Output: Decodable>(
        into table: String,
        payload: Input
    ) async throws -> Output {
        let token = try await currentToken()
        var req = URLRequest(url: baseURL(path: table))
        req.httpMethod = "POST"
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.setValue("application/vnd.pgrst.object+json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(payload)
        let (data, _) = try await perform(&req, accessToken: token)
        return try decoder.decode(Output.self, from: data)
    }

    /// Insert sin retornar body.
    static func insertVoid<Input: Encodable>(
        into table: String,
        payload: Input
    ) async throws {
        let token = try await currentToken()
        var req = URLRequest(url: baseURL(path: table))
        req.httpMethod = "POST"
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(payload)
        _ = try await perform(&req, accessToken: token)
    }

    // MARK: - UPSERT
    /// Upsert retornando la fila.
    static func upsert<Input: Encodable, Output: Decodable>(
        into table: String,
        payload: Input,
        onConflict: String
    ) async throws -> Output {
        let token = try await currentToken()
        var req = URLRequest(url: baseURL(
            path: table,
            query: [URLQueryItem(name: "on_conflict", value: onConflict)]
        ))
        req.httpMethod = "POST"
        req.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.setValue("application/vnd.pgrst.object+json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(payload)
        let (data, _) = try await perform(&req, accessToken: token)
        return try decoder.decode(Output.self, from: data)
    }

    // MARK: - UPDATE
    /// Update retornando la fila actualizada.
    static func update<Input: Encodable, Output: Decodable>(
        table: String,
        payload: Input,
        query: PgQuery
    ) async throws -> Output {
        let token = try await currentToken()
        var req = URLRequest(url: baseURL(path: table, query: query.urlItems))
        req.httpMethod = "PATCH"
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.setValue("application/vnd.pgrst.object+json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(payload)
        let (data, _) = try await perform(&req, accessToken: token)
        return try decoder.decode(Output.self, from: data)
    }

    /// Update sin retornar body.
    static func updateVoid<Input: Encodable>(
        table: String,
        payload: Input,
        query: PgQuery
    ) async throws {
        let token = try await currentToken()
        var req = URLRequest(url: baseURL(path: table, query: query.urlItems))
        req.httpMethod = "PATCH"
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(payload)
        _ = try await perform(&req, accessToken: token)
    }

    // MARK: - DELETE
    static func delete(
        from table: String,
        query: PgQuery
    ) async throws {
        let token = try await currentToken()
        var req = URLRequest(url: baseURL(path: table, query: query.urlItems))
        req.httpMethod = "DELETE"
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        _ = try await perform(&req, accessToken: token)
    }
}

private struct EmptyParams: Encodable {}
