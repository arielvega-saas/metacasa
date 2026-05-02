import Foundation

/// Cloud LLM fallback usando Claude Haiku 4.5 vía Edge Function `ai-proxy`.
///
/// Se invoca cuando FoundationModels (Apple Intelligence) no está disponible:
/// - Idioma del sistema no soportado (ej. Español Argentina)
/// - Device sin soporte de Apple Intelligence
/// - Apple Intelligence desactivado
/// - Modelo aún descargando
///
/// **Privacidad**: la API key de Anthropic NUNCA se expone al cliente.
/// El Edge Function valida JWT y forwarda la request usando el secret server-side.
///
/// **Tools**: Anthropic Claude tiene tool calling nativo. Implementamos el
/// loop tool_use → tool_result → continue client-side, así las tools tienen
/// acceso directo a TransactionService, BudgetService, etc.
///
/// **Rate limit**: 50 requests/día y 1000/mes por user (server-side).
/// Si se excede, retornamos un mensaje específico al user.
actor AnthropicProvider {
    static let shared = AnthropicProvider()
    private init() {}

    private let model = "claude-haiku-4-5-20251001"
    private let maxToolLoopIterations = 10
    private let maxOutputTokens = 1024

    enum AnthropicError: LocalizedError {
        case missingAccessToken
        case rateLimitExceeded(daily: Int, monthly: Int)
        case apiError(status: Int, detail: String)
        case invalidResponse
        case toolLoopExceeded

        var errorDescription: String? {
            switch self {
            case .missingAccessToken:
                "No hay sesión activa para usar el asistente cloud."
            case .rateLimitExceeded(let d, _):
                "Llegaste al límite de uso del asistente AI por hoy (\(d) consultas). Volvé mañana o probá las funciones que no necesitan AI."
            case .apiError(let s, _):
                "El asistente cloud falló (HTTP \(s)). Probá de nuevo en un momento."
            case .invalidResponse:
                "Respuesta inválida del asistente cloud."
            case .toolLoopExceeded:
                "El asistente se quedó dando vueltas. Probá reformulando la pregunta."
            }
        }
    }

    // MARK: - Public API

    /// Envía un mensaje al cloud LLM, ejecuta tool calls localmente, y retorna
    /// la respuesta final en texto.
    func respond(
        message: String,
        context: FinancialContext,
        householdId: UUID,
        userId: UUID,
        accessToken: String,
        history: [ChatTurn] = [],
        voiceMode: Bool = false
    ) async throws -> String {
        let systemPrompt = AISystemPromptV2.build(context: context, query: message, voiceMode: voiceMode)
        let toolHandler = await AIToolHandler(
            householdId: householdId,
            userId: userId,
            currency: context.currency
        )

        // Construir mensajes iniciales con history + nuevo user message.
        var messages: [APIMessage] = history.flatMap { turn -> [APIMessage] in
            switch turn {
            case .user(let text):
                return [APIMessage(role: "user", content: .text(text))]
            case .assistant(let text):
                return [APIMessage(role: "assistant", content: .text(text))]
            }
        }
        messages.append(APIMessage(role: "user", content: .text(message)))

        // Loop de tool calling.
        for _ in 0..<maxToolLoopIterations {
            let response = try await callProxy(
                accessToken: accessToken,
                system: systemPrompt,
                tools: AnthropicToolBuilder.allTools(),
                messages: messages
            )

            // Si el modelo terminó normalmente, devolvemos el texto.
            if response.stopReason == "end_turn" {
                return Self.extractText(from: response)
            }

            // Si pidió usar tools, ejecutarlas y continuar el loop.
            if response.stopReason == "tool_use" {
                let toolResults = try await executeToolUses(
                    response: response,
                    handler: toolHandler
                )

                // Append assistant turn (con tool_use blocks)
                messages.append(APIMessage(
                    role: "assistant",
                    content: .blocks(response.content)
                ))

                // Append user turn con tool_result blocks
                messages.append(APIMessage(
                    role: "user",
                    content: .blocks(toolResults)
                ))

                continue
            }

            // Cualquier otro stop_reason (max_tokens, stop_sequence) → devolver lo que haya.
            return Self.extractText(from: response)
        }

        throw AnthropicError.toolLoopExceeded
    }

    // MARK: - Tool execution

    @MainActor
    private func executeToolUses(
        response: APIResponse,
        handler: AIToolHandler
    ) async throws -> [APIBlock] {
        var results: [APIBlock] = []
        for block in response.content {
            guard block.type == "tool_use",
                  let id = block.id,
                  let name = block.name else { continue }

            let resultText: String
            do {
                resultText = try await AnthropicToolDispatcher.dispatch(
                    name: name,
                    input: block.input ?? [:],
                    handler: handler
                )
            } catch {
                resultText = "Error executing tool: \(error.localizedDescription)"
            }

            results.append(APIBlock(
                type: "tool_result",
                toolUseId: id,
                content: resultText
            ))
        }
        return results
    }

    // MARK: - Network

    private func callProxy(
        accessToken: String,
        system: String,
        tools: [APITool],
        messages: [APIMessage]
    ) async throws -> APIResponse {
        let url = Config.supabaseURL.appendingPathComponent("functions/v1/ai-proxy")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body = ProxyRequest(
            system: [SystemBlock(type: "text", text: system, cacheControl: CacheControl(type: "ephemeral"))],
            messages: messages,
            tools: tools,
            maxTokens: maxOutputTokens,
            temperature: 0.7
        )

        // No keyEncodingStrategy/keyDecodingStrategy: confiamos solo en los
        // CodingKeys explícitos de cada struct. Mezclar ambas estrategias
        // generaba un keyNotFound silencioso (la strategy convertía las keys
        // antes de aplicar los CodingKeys, dejándolos sin match).
        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(body)

        let (data, urlResponse) = try await URLSession.shared.data(for: req)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        if http.statusCode == 429 {
            if let err = try? JSONDecoder().decode(RateLimitError.self, from: data) {
                throw AnthropicError.rateLimitExceeded(
                    daily: err.dailyUsed ?? 0,
                    monthly: err.monthlyUsed ?? 0
                )
            }
            throw AnthropicError.rateLimitExceeded(daily: 0, monthly: 0)
        }

        if http.statusCode >= 400 {
            let detail = String(data: data, encoding: .utf8) ?? "?"
            throw AnthropicError.apiError(status: http.statusCode, detail: detail)
        }

        return try JSONDecoder().decode(APIResponse.self, from: data)
    }

    // MARK: - Helpers

    private static func extractText(from response: APIResponse) -> String {
        let texts = response.content
            .filter { $0.type == "text" }
            .compactMap { $0.text }
        return texts.joined(separator: "\n")
    }
}

// MARK: - Public types

enum ChatTurn: Sendable {
    case user(String)
    case assistant(String)
}

// MARK: - Anthropic API types (Codable)

private struct ProxyRequest: Encodable {
    let system: [SystemBlock]
    let messages: [APIMessage]
    let tools: [APITool]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case system, messages, tools, temperature
        case maxTokens = "max_tokens"
    }
}

private struct SystemBlock: Encodable {
    let type: String
    let text: String
    let cacheControl: CacheControl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }
}

private struct CacheControl: Encodable {
    let type: String
}

struct APIMessage: Codable, Sendable {
    let role: String
    let content: APIContent
}

enum APIContent: Codable, Sendable {
    case text(String)
    case blocks([APIBlock])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .blocks(let b): try container.encode(b)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .text(s)
        } else if let b = try? container.decode([APIBlock].self) {
            self = .blocks(b)
        } else {
            self = .text("")
        }
    }
}

struct APIBlock: Codable, Sendable {
    let type: String
    var text: String?
    var id: String?
    var name: String?
    var input: [String: AnyJSON]?
    var toolUseId: String?
    var content: String?

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
        case toolUseId = "tool_use_id"
        case content
    }

    init(type: String, toolUseId: String, content: String) {
        self.type = type
        self.toolUseId = toolUseId
        self.content = content
    }

    init(type: String, text: String) {
        self.type = type
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        input = try c.decodeIfPresent([String: AnyJSON].self, forKey: .input)
        toolUseId = try c.decodeIfPresent(String.self, forKey: .toolUseId)
        content = try c.decodeIfPresent(String.self, forKey: .content)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(input, forKey: .input)
        try c.encodeIfPresent(toolUseId, forKey: .toolUseId)
        try c.encodeIfPresent(content, forKey: .content)
    }
}

struct APITool: Codable, Sendable {
    let name: String
    let description: String
    let inputSchema: [String: AnyJSON]

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct APIResponse: Codable, Sendable {
    let id: String
    let type: String
    let role: String
    let content: [APIBlock]
    let stopReason: String

    enum CodingKeys: String, CodingKey {
        case id, type, role, content
        case stopReason = "stop_reason"
    }
}

private struct RateLimitError: Codable {
    let error: String?
    let dailyUsed: Int?
    let monthlyUsed: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case error, message
        case dailyUsed = "daily_used"
        case monthlyUsed = "monthly_used"
    }
}

/// Helper para encodear/decodear JSON dinámico (los inputs de tools son arbitrarios).
enum AnyJSON: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyJSON])
    case object([String: AnyJSON])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([AnyJSON].self) { self = .array(v); return }
        if let v = try? c.decode([String: AnyJSON].self) { self = .object(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
    var intValue: Int? {
        if case .int(let v) = self { return v }
        if case .double(let v) = self { return Int(v) }
        return nil
    }
    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        if case .int(let v) = self { return Double(v) }
        return nil
    }
    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
}
