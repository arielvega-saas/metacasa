import Foundation

/// Persiste sesiones del asistente IA en `Documents/chat-sessions/{householdId}/`.
///
/// **Por qué existe**: hasta ahora `AssistantViewModel.messages` vivía solo
/// en RAM. Si el usuario cerraba la app, el chat se perdía. Con este servicio:
///
/// 1. La sesión actual se persiste en `current.json` después de cada mensaje.
/// 2. Al cerrar el chat (sheet dismiss) se llama `closeSession()` que:
///    - Si hubo > 4 mensajes con contenido real, pide a Claude Haiku un
///      resumen de 2-3 oraciones.
///    - Guarda el resumen en `summaries.json` (índice global del hogar).
///    - Archiva `current.json` → `archived/{sessionId}.json`.
///    - Crea un `current.json` fresh para la próxima sesión.
/// 3. En la próxima apertura del chat, los últimos 3 summaries se inyectan
///    al system prompt como `=== PREVIOUS CONVERSATIONS ===` — memoria
///    conversacional efectivamente "infinita" sin saturar el context window.
///
/// **Privacy**: los JSON viven en el sandbox de la app, encriptados a nivel
/// FS por iOS (File Protection Class por default). Nada sale del device
/// para persistencia (solo para resumir, request a `ai-proxy` con JWT).
///
/// **Multi-hogar**: cada hogar tiene su propio directorio. Cuando el user
/// cambia de hogar, se carga la sesión del nuevo hogar (sin leak cruzado).
actor ChatPersistenceService {
    static let shared = ChatPersistenceService()
    private init() {}

    // MARK: - Public API

    /// Carga la sesión current del hogar, o crea una nueva si no existe.
    func loadOrCreateCurrent(householdId: UUID, userId: UUID) -> ChatSessionRecord {
        let url = currentSessionURL(householdId: householdId)
        if let session = try? loadSession(at: url),
           session.householdId == householdId,
           !session.isClosed {
            return session
        }
        let fresh = ChatSessionRecord(
            id: UUID(),
            householdId: householdId,
            userId: userId,
            createdAt: Date(),
            lastUpdatedAt: Date(),
            summary: nil,
            isClosed: false,
            messages: []
        )
        try? saveSession(fresh, to: url)
        return fresh
    }

    /// Agrega un mensaje a la sesión current y persiste.
    func appendMessage(
        _ message: ChatMessageRecord,
        householdId: UUID,
        userId: UUID
    ) {
        var session = loadOrCreateCurrent(householdId: householdId, userId: userId)
        session.messages.append(message)
        session.lastUpdatedAt = Date()
        try? saveSession(session, to: currentSessionURL(householdId: householdId))
    }

    /// Lee los últimos N summaries del hogar para inyectar al system prompt.
    /// Por default 3 — suficiente para memoria sin inflar tokens.
    func recentSummaries(householdId: UUID, limit: Int = 3) -> [String] {
        guard let index = try? loadSummaryIndex(householdId: householdId) else {
            return []
        }
        return index.entries
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0.summary }
    }

    /// Lee toda la sesión actual (para hidratar la UI al abrir el chat).
    func loadCurrent(householdId: UUID, userId: UUID) -> ChatSessionRecord {
        return loadOrCreateCurrent(householdId: householdId, userId: userId)
    }

    /// Cierra la sesión actual: si tiene contenido suficiente, genera un
    /// resumen via Claude Haiku, lo guarda en el índice, y archiva el JSON.
    ///
    /// Si la sesión es trivial (≤ 4 mensajes con contenido) o no hay token
    /// activo, se descarta sin generar resumen — no vale la latencia.
    func closeAndSummarize(householdId: UUID, userId: UUID, accessToken: String?) async {
        var session = loadOrCreateCurrent(householdId: householdId, userId: userId)

        let realMessages = session.messages.filter { !$0.content.isEmpty && $0.role != .system }
        guard realMessages.count > 4 else {
            // Sesión trivial — descartar sin resumir. Se reusa el JSON vacío.
            session.messages = []
            session.lastUpdatedAt = Date()
            try? saveSession(session, to: currentSessionURL(householdId: householdId))
            return
        }

        // Generar resumen via Claude Haiku si tenemos JWT.
        if let token = accessToken {
            do {
                let summary = try await Self.summarizeViaHaiku(
                    messages: realMessages,
                    accessToken: token
                )
                session.summary = summary
                session.isClosed = true

                // Agregar al índice de summaries (top 20).
                var index = (try? loadSummaryIndex(householdId: householdId))
                    ?? ChatSummaryIndex(entries: [])
                index.entries.append(ChatSummaryEntry(
                    id: UUID(),
                    sessionId: session.id,
                    createdAt: session.createdAt,
                    summary: summary,
                    messageCount: realMessages.count
                ))
                // Cap a 20 más recientes.
                if index.entries.count > 20 {
                    index.entries = Array(index.entries.suffix(20))
                }
                try saveSummaryIndex(index, householdId: householdId)

                // Archivar la sesión.
                let archivedURL = archivedSessionURL(householdId: householdId, sessionId: session.id)
                try saveSession(session, to: archivedURL)
            } catch {
                NSLog("[ChatPersistence] summarize failed: \(error.localizedDescription)")
            }
        }

        // Crear current.json fresh para la próxima sesión.
        let fresh = ChatSessionRecord(
            id: UUID(),
            householdId: householdId,
            userId: userId,
            createdAt: Date(),
            lastUpdatedAt: Date(),
            summary: nil,
            isClosed: false,
            messages: []
        )
        try? saveSession(fresh, to: currentSessionURL(householdId: householdId))
    }

    // MARK: - Rotación de la conversación

    /// Cuánto vale "la conversación de ahora".
    ///
    /// Volver al asistente dentro de esta ventana retoma lo que venías
    /// hablando; más tarde, abrir el asistente empieza de cero. Media hora es
    /// el corte natural de una tarea acá: cargar los gastos del finde, revisar
    /// el mes. Volver al otro día es otro tema, y arrastrar el anterior sólo
    /// confunde —al usuario, que ve una pantalla que no pidió, y al modelo,
    /// que arrastra contexto viejo.
    static let ventanaDeContinuidad: TimeInterval = 30 * 60

    /// Archiva la conversación actual y deja una limpia.
    ///
    /// **Devuelve la vieja para que el llamador la resuma en background**: el
    /// resumen pega a la red y no puede demorar la apertura del chat. Por eso
    /// esta parte es sincrónica y local, y la del resumen va aparte
    /// (`resumirEIndexar`). `nil` si no había nada que rotar.
    ///
    /// Con `soloSiVencio: false` rota igual — es el "empezar de nuevo" manual.
    func rotar(
        householdId: UUID,
        userId: UUID,
        soloSiVencio: Bool,
        ahora: Date = Date()
    ) -> ChatSessionRecord? {
        var session = loadOrCreateCurrent(householdId: householdId, userId: userId)
        let reales = session.messages.filter { !$0.content.isEmpty && $0.role != .system }
        guard !reales.isEmpty else { return nil }
        if soloSiVencio,
           ahora.timeIntervalSince(session.lastUpdatedAt) <= Self.ventanaDeContinuidad {
            return nil
        }

        session.isClosed = true
        // Sellar el cierre con `ahora`: el JSON guarda ISO8601 **sin
        // fracciones de segundo**, así que si el orden del historial dependiera
        // del último mensaje, dos charlas cerradas en el mismo segundo
        // quedarían empatadas y el orden sería indefinido.
        session.lastUpdatedAt = ahora
        try? saveSession(
            session,
            to: archivedSessionURL(householdId: householdId, sessionId: session.id)
        )
        let fresh = ChatSessionRecord(
            id: UUID(),
            householdId: householdId,
            userId: userId,
            createdAt: ahora,
            lastUpdatedAt: ahora,
            summary: nil,
            isClosed: false,
            messages: []
        )
        try? saveSession(fresh, to: currentSessionURL(householdId: householdId))
        return session
    }

    /// Resume una sesión ya archivada y la agrega al índice que alimenta la
    /// memoria del asistente. Pensado para correr en background después de
    /// `rotar`: si falla, se pierde el resumen, no la conversación.
    func resumirEIndexar(_ session: ChatSessionRecord, accessToken: String?) async {
        guard let token = accessToken else { return }
        let reales = session.messages.filter { !$0.content.isEmpty && $0.role != .system }
        // Una charla de cuatro mensajes no tiene nada que recordar.
        guard reales.count > 4 else { return }
        do {
            let summary = try await Self.summarizeViaHaiku(messages: reales, accessToken: token)
            var index = (try? loadSummaryIndex(householdId: session.householdId))
                ?? ChatSummaryIndex(entries: [])
            index.entries.append(ChatSummaryEntry(
                id: UUID(),
                sessionId: session.id,
                createdAt: session.createdAt,
                summary: summary,
                messageCount: reales.count
            ))
            if index.entries.count > 20 {
                index.entries = Array(index.entries.suffix(20))
            }
            try saveSummaryIndex(index, householdId: session.householdId)

            var actualizada = session
            actualizada.summary = summary
            try saveSession(
                actualizada,
                to: archivedSessionURL(householdId: session.householdId, sessionId: session.id)
            )
        } catch {
            NSLog("[ChatPersistence] resumen diferido falló: \(error.localizedDescription)")
        }
    }

    // MARK: - Historial

    /// Una conversación pasada, lista para mostrar en el historial.
    struct ConversacionArchivada: Identifiable, Sendable, Equatable {
        let id: UUID
        let fecha: Date
        /// Primer mensaje del usuario, recortado. Es mejor título que la fecha:
        /// uno reconoce "cargá estos gastos del finde" mucho antes que
        /// "7 de agosto, 20:14".
        let titulo: String
        let resumen: String?
        let mensajes: Int
    }

    /// Las conversaciones archivadas del hogar, de la más reciente a la más
    /// vieja.
    ///
    /// Lee el directorio y decodifica cada JSON. Con el tope de 50 y sesiones
    /// de decenas de mensajes esto es despreciable, y evita mantener un índice
    /// paralelo que se puede desincronizar del contenido real —el índice de
    /// `summaries.json` existe para el prompt, no para la UI, y sólo guarda 20—.
    func conversacionesArchivadas(householdId: UUID, limite: Int = 50) -> [ConversacionArchivada] {
        let dir = sessionsDir(householdId: householdId)
            .appendingPathComponent("archived", isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        let sesiones = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? loadSession(at: $0) }
            .filter { !$0.messages.isEmpty }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
            .prefix(limite)

        return sesiones.map { s in
            let primeroDelUsuario = s.messages.first {
                $0.role == .user && !$0.content.isEmpty
            }?.content
            let titulo = Self.recortar(primeroDelUsuario ?? s.summary ?? "Conversación")
            return ConversacionArchivada(
                id: s.id,
                fecha: s.lastUpdatedAt,
                titulo: titulo,
                resumen: s.summary,
                mensajes: s.messages.count { !$0.content.isEmpty && $0.role != .system }
            )
        }
    }

    /// La conversación completa, para poder leerla.
    func cargarArchivada(householdId: UUID, sessionId: UUID) -> ChatSessionRecord? {
        try? loadSession(at: archivedSessionURL(householdId: householdId, sessionId: sessionId))
    }

    /// Retoma una conversación vieja: archiva la actual y deja la elegida como
    /// la de ahora.
    ///
    /// Devuelve la sesión que pasa a ser la actual, o `nil` si no existe.
    /// Nunca borra: la que estaba en curso se archiva igual que siempre, así
    /// que retomar no puede hacerte perder lo que venías hablando.
    func retomar(householdId: UUID, userId: UUID, sessionId: UUID) -> ChatSessionRecord? {
        guard var elegida = cargarArchivada(householdId: householdId, sessionId: sessionId) else {
            return nil
        }
        _ = rotar(householdId: householdId, userId: userId, soloSiVencio: false)

        elegida.isClosed = false
        elegida.lastUpdatedAt = Date()
        try? saveSession(elegida, to: currentSessionURL(householdId: householdId))
        return elegida
    }

    private static func recortar(_ s: String, _ tope: Int = 70) -> String {
        let limpio = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard limpio.count > tope else { return limpio }
        return String(limpio.prefix(tope)) + "…"
    }

    /// Reset total — útil cuando el user elimina su hogar.
    func clearAll(householdId: UUID) {
        let dir = sessionsDir(householdId: householdId)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - File layout

    private func documentsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func sessionsDir(householdId: UUID) -> URL {
        documentsDir()
            .appendingPathComponent("chat-sessions", isDirectory: true)
            .appendingPathComponent(householdId.uuidString, isDirectory: true)
    }

    private func currentSessionURL(householdId: UUID) -> URL {
        sessionsDir(householdId: householdId).appendingPathComponent("current.json")
    }

    private func archivedSessionURL(householdId: UUID, sessionId: UUID) -> URL {
        sessionsDir(householdId: householdId)
            .appendingPathComponent("archived", isDirectory: true)
            .appendingPathComponent("\(sessionId.uuidString).json")
    }

    private func summaryIndexURL(householdId: UUID) -> URL {
        sessionsDir(householdId: householdId).appendingPathComponent("summaries.json")
    }

    // MARK: - I/O

    private func loadSession(at url: URL) throws -> ChatSessionRecord {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChatSessionRecord.self, from: data)
    }

    private func saveSession(_ session: ChatSessionRecord, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(session)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private func loadSummaryIndex(householdId: UUID) throws -> ChatSummaryIndex {
        let data = try Data(contentsOf: summaryIndexURL(householdId: householdId))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChatSummaryIndex.self, from: data)
    }

    private func saveSummaryIndex(_ index: ChatSummaryIndex, householdId: UUID) throws {
        let url = summaryIndexURL(householdId: householdId)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    // MARK: - Summarization via Claude Haiku

    /// Resume una sesión usando Claude Haiku 4.5 via el edge function ai-proxy.
    /// El prompt instruye a producir un resumen objetivo, 2-3 oraciones,
    /// preservando hechos clave (números, decisiones, acciones tomadas).
    private static func summarizeViaHaiku(
        messages: [ChatMessageRecord],
        accessToken: String
    ) async throws -> String {
        let transcript = messages.map { m in
            let role = m.role == .user ? "User" : "Assistant"
            return "\(role): \(m.content)"
        }.joined(separator: "\n\n")

        let systemPrompt = """
        You are a summarization assistant. Summarize the following finance-app \
        conversation in 2-3 short sentences in the same language as the conversation. \
        Preserve concrete facts: amounts, dates, categories, actions taken, decisions \
        made, goals set. Skip pleasantries. Do not invent. The summary will be shown \
        to the same user in a future session — write in second person ("Hablaste de…").
        """

        let url = Config.supabaseURL.appendingPathComponent("functions/v1/ai-proxy")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.timeoutInterval = 15

        let body: [String: Any] = [
            "system": [
                ["type": "text", "text": systemPrompt]
            ],
            "messages": [
                ["role": "user", "content": transcript]
            ],
            "max_tokens": 200,
            "temperature": 0.3
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(
                domain: "ChatPersistence",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: "summarize HTTP error"]
            )
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" }),
              let text = firstText["text"] as? String else {
            throw NSError(
                domain: "ChatPersistence",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "summarize: unexpected response shape"]
            )
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
