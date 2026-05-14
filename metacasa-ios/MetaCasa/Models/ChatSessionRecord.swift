import Foundation

/// Una sesión de conversación del asistente IA persistida en disco.
/// Cada hogar tiene como mucho 1 sesión `current` abierta más N sesiones
/// `archived` con su `summary` generado por Claude Haiku al cerrarse.
///
/// Persistencia: JSON files en `Documents/chat-sessions/{householdId}/`.
/// Decisión: NO SwiftData. La app no lo usa en ningún otro modelo y
/// agregar un ModelContainer solo para chat agrega complejidad sin upside.
struct ChatSessionRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let householdId: UUID
    let userId: UUID
    let createdAt: Date
    var lastUpdatedAt: Date
    /// Resumen generado por Claude Haiku al cerrar la sesión. `nil` mientras
    /// está abierta. Se inyecta al system prompt de futuras sesiones para
    /// memoria conversacional "infinita" sin saturar el context window.
    var summary: String?
    var isClosed: Bool
    var messages: [ChatMessageRecord]
}

/// Mensaje individual persistido. NO incluye attachments (UIImage no es
/// Codable razonable y los recibos ya fueron consumidos al momento de
/// extraer info). Sí guardamos un flag `hadAttachment` para que el LLM
/// sepa que en ese turno hubo una imagen.
struct ChatMessageRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let hadAttachment: Bool

    enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        hadAttachment: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.hadAttachment = hadAttachment
    }
}

/// Índice de resúmenes históricos. Persistido en
/// `Documents/chat-sessions/{householdId}/summaries.json`.
/// Mantenemos solo los últimos 20 — los más viejos se descartan para no
/// inflar el JSON ni el context window.
struct ChatSummaryIndex: Codable, Sendable {
    var entries: [ChatSummaryEntry]
}

struct ChatSummaryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionId: UUID
    let createdAt: Date
    let summary: String
    let messageCount: Int
}
