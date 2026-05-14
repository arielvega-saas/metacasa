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
        /// Anthropic decidió invocar una tool durante un stream — necesitamos
        /// fallback al método no-streaming porque el loop de tool_use requiere
        /// el response completo. El caller atrapa este error y reintenta con
        /// `respond(...)`.
        case toolCallInStream

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
            case .toolCallInStream:
                "Necesito ejecutar una acción — cambiando a modo no-streaming."
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
        voiceMode: Bool = false,
        pastSummaries: [String] = []
    ) async throws -> String {
        let systemPrompt = AISystemPromptV2.build(
            context: context,
            query: message,
            voiceMode: voiceMode,
            pastSummaries: pastSummaries
        )
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

    /// Envía un mensaje al cloud LLM con **streaming SSE** — emite deltas de
    /// texto a medida que el modelo los genera. TTFT cae de ~3s (no-streaming)
    /// a ~500ms. Para chat texto da experiencia tipo ChatGPT moderna.
    ///
    /// **Limitación**: si el modelo decide invocar una tool durante el stream,
    /// throw `toolCallInStream` — el caller debe atrapar y caer al método
    /// `respond(...)` no-streaming, que maneja el loop tool_use → tool_result
    /// → continue. La razón: parsear tool_use inputs JSON parcial es frágil.
    ///
    /// Voice mode NO usa este método (encola oraciones completas para TTS).
    nonisolated func respondStream(
        message: String,
        context: FinancialContext,
        accessToken: String,
        history: [ChatTurn] = [],
        voiceMode: Bool = false,
        pastSummaries: [String] = []
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.streamProxy(
                        message: message,
                        context: context,
                        accessToken: accessToken,
                        history: history,
                        voiceMode: voiceMode,
                        pastSummaries: pastSummaries,
                        onDelta: { delta in continuation.yield(delta) }
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Implementación interna del streaming. Llama al edge function ai-proxy
    /// con `stream: true`, lee la respuesta como text/event-stream, parsea
    /// líneas `data: {json}` y extrae los `content_block_delta` con
    /// `delta.type == "text_delta"`. Throw `toolCallInStream` si detecta
    /// un `content_block_start` con `content_block.type == "tool_use"`.
    private func streamProxy(
        message: String,
        context: FinancialContext,
        accessToken: String,
        history: [ChatTurn],
        voiceMode: Bool,
        pastSummaries: [String],
        onDelta: @escaping (String) -> Void
    ) async throws {
        let systemPrompt = AISystemPromptV2.build(
            context: context,
            query: message,
            voiceMode: voiceMode,
            pastSummaries: pastSummaries
        )

        // Construir messages (mismo flow que respond, pero sin imagen — el
        // streaming inicial es solo para chat texto).
        var messages: [APIMessage] = history.flatMap { turn -> [APIMessage] in
            switch turn {
            case .user(let text):
                return [APIMessage(role: "user", content: .text(text))]
            case .assistant(let text):
                return [APIMessage(role: "assistant", content: .text(text))]
            }
        }
        messages.append(APIMessage(role: "user", content: .text(message)))

        let url = Config.supabaseURL.appendingPathComponent("functions/v1/ai-proxy")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body = ProxyRequest(
            system: [SystemBlock(type: "text", text: systemPrompt, cacheControl: CacheControl(type: "ephemeral"))],
            messages: messages,
            tools: AnthropicToolBuilder.allTools(),
            maxTokens: maxOutputTokens,
            temperature: 0.7,
            stream: true
        )

        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(body)

        let (asyncBytes, urlResponse) = try await URLSession.shared.bytes(for: req)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        if http.statusCode == 429 {
            throw AnthropicError.rateLimitExceeded(daily: 0, monthly: 0)
        }
        if http.statusCode >= 400 {
            // Drenar body para diagnostic.
            var detail = ""
            for try await line in asyncBytes.lines {
                detail += line + "\n"
                if detail.count > 500 { break }
            }
            throw AnthropicError.apiError(status: http.statusCode, detail: detail)
        }

        // Parser SSE: cada evento tiene la forma:
        //   event: <type>\n
        //   data: <json>\n
        //   \n
        // Solo nos interesan las líneas `data: ...`. Ignoramos `event:` y
        // separadores vacíos.
        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard let data = jsonStr.data(using: .utf8) else { continue }

            // Detectar tool_use temprano para cortar el stream.
            // Estructura de content_block_start con tool_use:
            //   {"type":"content_block_start","index":N,"content_block":{"type":"tool_use",...}}
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let type = obj["type"] as? String

                if type == "content_block_start",
                   let block = obj["content_block"] as? [String: Any],
                   (block["type"] as? String) == "tool_use" {
                    throw AnthropicError.toolCallInStream
                }

                if type == "content_block_delta",
                   let delta = obj["delta"] as? [String: Any],
                   (delta["type"] as? String) == "text_delta",
                   let text = delta["text"] as? String {
                    onDelta(text)
                }

                if type == "message_stop" {
                    return
                }
            }
        }
    }

    /// Extrae UNA o VARIAS transacciones de UNA o VARIAS imágenes (recibos,
    /// tickets, screenshots de listados de wallet, etc.) usando Claude Haiku
    /// con visión. Las imágenes van directo al modelo — no hay OCR intermedio.
    /// El modelo procesa todas las imágenes en una sola request y devuelve un
    /// array con TODOS los gastos detectados, indistintamente de qué imagen
    /// vinieron.
    func parseImageReceipts(jpegDatas: [Data], accessToken: String) async throws -> [ParsedReceipt] {
        guard !jpegDatas.isEmpty else { return [] }

        let system = """
        Sos un experto en analizar imágenes de recibos, tickets, comprobantes y screenshots de listados de transacciones (de wallets como MercadoPago, Naranja X, Brubank, Uala, o cualquier app financiera). Tu única salida debe ser un JSON válido — sin explicaciones, sin markdown, sin bloques de código.

        Estructura esperada:
        {"transactions": [
          {"amount": <número decimal positivo>, "date": "<YYYY-MM-DD o null>", "merchant": "<nombre o null>", "currency": "<código ISO o null>", "category": "<categoría o null>"}
        ]}

        Si te paso varias imágenes, agregá los gastos de TODAS al mismo array (no las separes).

        REGLAS DE LECTURA DE MONTOS — críticas, leelas con atención:
        - Mirá el número exactamente como aparece. NO redondees, NO inventes decimales que no están.
        - El separador de miles en español rioplatense es "." y el decimal es ",". "$ 23.100" = 23100.00 (veintitres mil cien). "$ 1.250,50" = 1250.50.
        - El separador de miles en inglés es "," y el decimal es ".". "$1,250.50" = 1250.50.
        - Si ves "$ 4.090" sin coma decimal → es 4090, NO 4.09 ni 4090.00 con .00 espureo.
        - Si ves "$23.100" → es 23100, NO 23.10.
        - Cuando hay duda entre un número grande sin decimales y uno pequeño con decimales, mirá el contexto: en Argentina los gastos de wallet suelen ser miles ($1.000-$50.000), no centavos.
        - Solo tomá el monto del gasto en sí, ignorá saldos, totales acumulados, números de operación, CBU/alias, fechas.

        REGLAS GENERALES:
        - Si es UN ticket/recibo de compra → un solo elemento por imagen.
        - Si es un LISTADO de movimientos de wallet → un elemento por cada gasto.
        - Solo incluí GASTOS (transferencias enviadas, pagos, débitos). Ignorá ingresos, transferencias recibidas y saldos.
        - amount: SIEMPRE positivo (valor absoluto del gasto).
        - merchant: nombre limpio del comercio o destinatario. Sin "Transferencia a", sin CUIT, sin números de operación, sin "Pago de servicio".
        - currency: detectá por símbolo o contexto. "$" en wallets argentinas (Naranja X, Mercado Pago, Brubank, Uala) → "ARS". "R$" → "BRL". "€" → "EUR". null si no hay info clara.
        - date: si la fila no tiene fecha pero hay un encabezado cercano (ej. "4 de mayo"), usá esa. Año actual si no se ve.
        - category: una de "Alimentación", "Transporte", "Salud", "Suscripciones", "Servicios", "Ropa", "Entretenimiento", "Educación", "Hogar", "Transferencias", "Otros".

        Si no identificás NINGÚN gasto → devolvé {"transactions": []}.
        """

        var blocks: [APIBlock] = jpegDatas.map { APIBlock(image: $0) }
        let prompt = jpegDatas.count == 1
            ? "Identificá todos los gastos de esta imagen y devolveme el JSON."
            : "Identificá todos los gastos de las \(jpegDatas.count) imágenes y devolveme el JSON consolidado."
        blocks.append(APIBlock(type: "text", text: prompt))

        let response = try await callProxy(
            accessToken: accessToken,
            system: system,
            tools: [],
            messages: [APIMessage(role: "user", content: .blocks(blocks))]
        )

        let jsonText = Self.extractText(from: response)
        return try Self.decodeReceiptsJSON(jsonText)
    }

    private static func decodeReceiptsJSON(_ raw: String) throws -> [ParsedReceipt] {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AnthropicError.invalidResponse
        }

        struct ReceiptDTO: Decodable {
            let amount: Double?
            let date: String?
            let merchant: String?
            let currency: String?
            let category: String?
        }
        struct Wrapper: Decodable {
            let transactions: [ReceiptDTO]
        }

        let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        return wrapper.transactions.compactMap { dto -> ParsedReceipt? in
            guard let amount = dto.amount, amount > 0 else { return nil }
            let date: Date? = dto.date.flatMap { dateFormatter.date(from: $0) }
            return ParsedReceipt(
                amount: Decimal(amount),
                date: date,
                merchant: dto.merchant?.isEmpty == false ? dto.merchant : nil,
                currency: dto.currency?.isEmpty == false ? dto.currency : nil,
                category: dto.category?.isEmpty == false ? dto.category : nil,
                rawLines: []
            )
        }
    }

    /// Extrae datos estructurados de un recibo a partir del texto OCR usando
    /// Claude Haiku. Mucho más robusto que el parser regex en `ReceiptParser`
    /// — entiende formatos sin decimales, líneas de header de ticket, idiomas
    /// mezclados y devuelve la categoría sugerida ya en español.
    func parseReceipt(text: String, accessToken: String) async throws -> ParsedReceipt {
        let system = """
        Sos un parser de recibos y tickets de compra. Recibís el texto crudo extraído por OCR (puede estar desordenado o con errores) y respondés ÚNICAMENTE con un objeto JSON válido — sin explicaciones, sin markdown, sin código de bloque.

        Estructura esperada:
        {"amount": <número con decimales o null>, "date": "<YYYY-MM-DD o null>", "merchant": "<nombre del comercio o null>", "currency": "<USD|ARS|EUR|BRL|MXN|UYU|CLP|PEN|COP o null>", "category": "<categoría sugerida o null>"}

        Reglas:
        - amount: el TOTAL pagado (no subtotales, no códigos de barras, no números de transacción ni CUIT).
        - merchant: solo el nombre del comercio. NO incluyas "Ticket Nº", "CUIT", domicilios, ni números.
        - currency: detectá por símbolo ($, €, R$), código (USD, ARS) o contexto. null si no es claro.
        - category: una de "Alimentación", "Transporte", "Salud", "Suscripciones", "Servicios", "Ropa", "Entretenimiento", "Educación", "Hogar", "Otros". Devolvé null si no podés inferir.
        - Si NO podés determinar un campo con razonable confianza, devolvé null para ese campo.
        """

        let response = try await callProxy(
            accessToken: accessToken,
            system: system,
            tools: [],
            messages: [APIMessage(role: "user", content: .text("Texto OCR del recibo:\n\(text)"))]
        )

        let jsonText = Self.extractText(from: response)
        return try Self.decodeReceiptJSON(jsonText, rawText: text)
    }

    private static func decodeReceiptJSON(_ raw: String, rawText: String) throws -> ParsedReceipt {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AnthropicError.invalidResponse
        }

        struct ReceiptDTO: Decodable {
            let amount: Double?
            let date: String?
            let merchant: String?
            let currency: String?
            let category: String?
        }

        let dto = try JSONDecoder().decode(ReceiptDTO.self, from: data)

        let date: Date? = {
            guard let dateStr = dto.date, !dateStr.isEmpty else { return nil }
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.date(from: dateStr)
        }()

        let amount: Decimal? = dto.amount.flatMap {
            $0 > 0 ? Decimal($0) : nil
        }

        return ParsedReceipt(
            amount: amount,
            date: date,
            merchant: dto.merchant?.isEmpty == false ? dto.merchant : nil,
            currency: dto.currency?.isEmpty == false ? dto.currency : nil,
            category: dto.category?.isEmpty == false ? dto.category : nil,
            rawLines: rawText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
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
        var req = URLRequest(url: url, timeoutInterval: 45)
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
    var stream: Bool = false

    enum CodingKeys: String, CodingKey {
        case system, messages, tools, temperature, stream
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

struct ImageSource: Codable, Sendable {
    let type: String       // "base64"
    let mediaType: String  // "image/jpeg"
    let data: String       // base64-encoded bytes

    enum CodingKeys: String, CodingKey {
        case type, data
        case mediaType = "media_type"
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
    var source: ImageSource?

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, source
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

    init(image jpegData: Data) {
        self.type = "image"
        self.source = ImageSource(
            type: "base64",
            mediaType: "image/jpeg",
            data: jpegData.base64EncodedString()
        )
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
        source = try c.decodeIfPresent(ImageSource.self, forKey: .source)
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
        try c.encodeIfPresent(source, forKey: .source)
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
