import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Wrapper del framework FoundationModels (Apple Intelligence, iOS 26+).
///
/// Se usa desde `AIAssistantService.ask(...)` — si el dispositivo soporta
/// Apple Intelligence, ruteamos acá primero. Si falla (no disponible,
/// error de modelo, device sin support), el caller hace fallback al motor
/// estadístico local.
///
/// Guardrails del system prompt viven en `systemPrompt(context:)`:
/// - Scope estricto a uso de la app + análisis de datos del usuario.
/// - No inventar números; pedir más datos si faltan.
/// - No dar consejos de inversión específicos.
/// - Idioma es-AR por default.
///
/// **Nota sobre la API de FoundationModels (iOS 26+)**: la API puede variar
/// entre versiones menores. Si el build falla por API mismatch, ajustar los
/// call sites dentro de `ask(...)` — el resto de la app sigue andando con
/// el fallback estadístico en `AIAssistantService`.
enum FoundationModelsProvider {
    enum FMError: LocalizedError {
        case notSupported
        case modelUnavailable(reason: String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notSupported:               "Apple Intelligence requiere iOS 26+."
            case .modelUnavailable(let r):    "Modelo on-device no disponible: \(r)"
            case .invalidResponse:            "Respuesta inválida del modelo."
            }
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    static func ask(
        message: String,
        context: FinancialContext,
        householdId: UUID? = nil,
        userId: UUID? = nil
    ) async throws -> String {
        if let hid = householdId, let uid = userId {
            let response = try await AIConversationManager.shared.respond(
                to: message,
                context: context,
                householdId: hid,
                userId: uid
            )
            return cleanRioplatense(response)
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable(reason: describeAvailability(model.availability))
        }

        // FoundationModels on-device tiene context window de ~4k tokens —
        // usamos el knowledge base compact + howTo selectivo por keyword.
        let prompt = AISystemPromptV2.build(
            context: context,
            query: message,
            useFullKnowledge: false
        )
        let session = LanguageModelSession(
            model: model,
            instructions: Instructions(prompt)
        )

        let response = try await session.respond(to: message)
        return cleanRioplatense(response.content)
    }

    /// Versión streaming. Llama el callback `onSentence` cada vez que el LLM
    /// completa una oración (boundary: `.`, `?`, `!`, `\n`). Permite que el TTS
    /// empiece a hablar antes de que termine la respuesta — fluidez tipo ChatGPT.
    ///
    /// Usado por VoiceConversationManager en voice mode. Para chat de texto,
    /// `ask(...)` directo es más simple porque no hay TTS para alimentar.
    @available(iOS 26.0, *)
    static func streamAsk(
        message: String,
        context: FinancialContext,
        householdId: UUID,
        userId: UUID,
        onSentence: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable(reason: describeAvailability(model.availability))
        }

        // Voice mode usa prompt lite (sin knowledge base completa ni tools)
        // para mantener el contexto bajo los ~4K tokens del modelo on-device.
        // Tools saturan el window y son confusas en voz — para voice solo chat.
        let prompt = AISystemPromptV2.buildLiteVoice(context: context)

        let session = LanguageModelSession(
            model: model,
            instructions: Instructions(prompt)
        )

        let stream = session.streamResponse(to: message)
        var fullText = ""
        var sentenceBuffer = ""

        for try await chunk in stream {
            // FoundationModels streaming entrega `Response.Snapshot` con `content`
            // como string acumulativo. Tomamos el delta nuevo.
            let chunkContent = chunk.content
            let newText = String(chunkContent.dropFirst(fullText.count))
            guard !newText.isEmpty else { continue }

            fullText = chunkContent
            sentenceBuffer += newText

            // Buscar boundaries de oración para emitir.
            while let endIdx = findSentenceEnd(in: sentenceBuffer) {
                let sentence = String(sentenceBuffer[..<endIdx])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let restStart = sentenceBuffer.index(after: sentenceBuffer.index(sentenceBuffer.startIndex, offsetBy: sentenceBuffer.distance(from: sentenceBuffer.startIndex, to: endIdx)))
                sentenceBuffer = String(sentenceBuffer[restStart...])
                if !sentence.isEmpty {
                    onSentence(sentence)
                }
            }
        }

        // Flush último chunk si quedó algo sin punctuación final.
        let leftover = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !leftover.isEmpty {
            onSentence(leftover)
        }

        return cleanRioplatense(fullText)
    }

    /// Encuentra el índice del próximo terminador de oración en el buffer.
    /// Boundary: . ! ? \n seguido de espacio o fin de string.
    private static func findSentenceEnd(in s: String) -> String.Index? {
        let terminators: Set<Character> = [".", "!", "?", "\n"]
        var idx = s.startIndex
        while idx < s.endIndex {
            if terminators.contains(s[idx]) {
                let next = s.index(after: idx)
                // Punto seguido de espacio/end → es boundary real.
                // Punto seguido de letra (ej. "$2.5M") → no es boundary.
                if next == s.endIndex || s[next].isWhitespace || s[next].isNewline {
                    return idx
                }
            }
            idx = s.index(after: idx)
        }
        return nil
    }

    /// Detecta si el query pide un procedimiento ("cómo X", "dónde está Y",
    /// "cambiar Z"). Si sí, hacemos routing y agregamos solo el sub-bloque
    /// relevante al prompt.
    static func needsHowTo(_ query: String) -> Bool {
        let q = query.lowercased()
        let triggers = [
            "cómo ", "como ", "dónde ", "donde ", "cambiar", "cambio ",
            "configurar", "configuro ", "agregar", "agrego ", "crear ",
            "creo ", "borrar", "borro", "eliminar", "elimino", "editar",
            "edito", "exportar", "importar", "compartir", "invitar",
            "activar", "desactivar", "ajust", "setting", "where", "how",
            "restablecer", "reset", "empezar de cero", "restaurar"
        ]
        return triggers.contains(where: { q.contains($0) })
    }

    /// Extrae del `howTo` solo los bloques relevantes al query (matching por
    /// keywords con palabras del query >3 chars). Esto evita meter los ~4KB
    /// completos del howTo y mantiene el prompt dentro del context window.
    /// Si no matchea nada, devuelve un fragmento corto que invita al modelo
    /// a recomendar el Help Center.
    static func relevantHowToBlocks(for query: String) -> String {
        let q = query.lowercased()
        // Stopwords cortas para evitar matches inútiles ("para", "como", etc.).
        let stopwords: Set<String> = [
            "para", "como", "cómo", "donde", "dónde", "esta", "está", "esto",
            "porque", "pero", "que", "qué", "con", "una", "uno", "más", "mas",
            "the", "and", "for", "this", "that", "with", "from", "what", "where", "how"
        ]
        let words = q.split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count > 3 && !stopwords.contains($0) }

        guard !words.isEmpty else {
            return "(Si el usuario pide un procedimiento específico, sugerile abrir Más → Ayuda — Help Center con 16 tópicos buscables.)"
        }

        // Cada bloque del howTo está separado por doble newline.
        let blocks = AppKnowledgeBase.howTo.components(separatedBy: "\n\n")
        var matched: [String] = []
        for block in blocks {
            let blockLower = block.lowercased()
            if words.contains(where: { blockLower.contains($0) }) {
                matched.append(block.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        if matched.isEmpty {
            return "(No tengo un procedimiento exacto. Sugerile abrir Más → Ayuda — Help Center con 16 tópicos buscables.)"
        }
        // Limitamos a 3 bloques max para no overflow.
        let top = matched.prefix(3).joined(separator: "\n\n")
        return "=== PROCEDIMIENTOS RELEVANTES ===\n\n\(top)"
    }

    /// Convierte la `Availability` del modelo en un mensaje legible para el user.
    /// Cubre los 4 casos posibles que reporta `SystemLanguageModel`:
    /// - `.unavailable(.deviceNotEligible)`: hardware no soporta Apple Intelligence
    /// - `.unavailable(.appleIntelligenceNotEnabled)`: feature deshabilitada en Settings
    /// - `.unavailable(.modelNotReady)`: modelo aún descargando o pendiente
    /// - `.unavailable(other)`: cualquier otro caso futuro
    @available(iOS 26.0, *)
    static func describeAvailability(_ availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return "disponible"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "este dispositivo no soporta Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence está desactivado. Activalo en Ajustes → Apple Intelligence y Siri."
            case .modelNotReady:
                return "el modelo se está descargando. Esperá unos minutos con el iPhone conectado a Wi-Fi y enchufado, después probá de nuevo."
            @unknown default:
                return "razón desconocida (\(String(describing: reason)))."
            }
        @unknown default:
            return "estado desconocido."
        }
    }

    /// Post-procesa la respuesta del modelo para corregir errores conjugales
    /// comunes — el on-device LLM mezcla voseo con formas inválidas. Solo
    /// reemplazamos formas que NO son válidas en ningún dialecto.
    @available(iOS 26.0, *)
    private static func cleanRioplatense(_ text: String) -> String {
        var t = text
        let fixes: [(String, String)] = [
            ("tenís", "tenés"),
            ("podís", "podés"),
            ("querís", "querés"),
            ("sabís", "sabés"),
            ("Tenís", "Tenés"),
            ("Podís", "Podés"),
            ("Querís", "Querés"),
            ("Sabís", "Sabés"),
        ]
        for (wrong, right) in fixes {
            t = t.replacingOccurrences(of: wrong, with: right)
        }
        return t
    }
    #else
    static func ask(message: String, context: FinancialContext) async throws -> String {
        throw FMError.notSupported
    }
    #endif

    /// System prompt con guardrails + knowledge base de la app + contexto
    /// financiero del usuario. Se construye cada vez que se invoca — refleja
    /// los datos actuales en vivo.
    ///
    /// Estructura del prompt:
    /// 1. Persona + scope + reglas duras (guardrails).
    /// 2. Mapa de navegación y features de la app (AppKnowledgeBase).
    /// 3. Procedimientos comunes ("cómo hago X").
    /// 4. Glosario de finanzas personales.
    /// 5. Principios de asesoría profesional.
    /// 6. Contexto financiero específico del usuario.
    ///
    /// El user ask llega aparte como turn de chat — el modelo combina ambos.
    static func systemPrompt(context: FinancialContext, query: String = "") -> String {
        // Knowledge base selectivo: si el query parece pedir un procedimiento,
        // hacemos routing y solo incluímos los bloques relevantes del `howTo`
        // (no los 4KB completos). Esto mantiene el prompt dentro del context
        // window del modelo on-device de Apple Intelligence.
        let knowledgeBase = needsHowTo(query)
            ? "\(AppKnowledgeBase.compact)\n\n\(relevantHowToBlocks(for: query))"
            : AppKnowledgeBase.compact
        let curr = context.currency
        let topCategoriesBlock: String
        if context.topCategories.isEmpty {
            topCategoriesBlock = "(sin gastos cargados este mes)"
        } else {
            topCategoriesBlock = context.topCategories.prefix(5).enumerated()
                .map { idx, item in
                    let share = context.gastosMonth > 0
                        ? Int((((item.total / context.gastosMonth) as NSDecimalNumber).doubleValue * 100).rounded())
                        : 0
                    return "  \(idx + 1). \(item.category): \(Money.format(item.total, currency: curr)) (\(share)% del total)"
                }
                .joined(separator: "\n")
        }
        let goalsBlock: String
        if context.activeGoalsSummary.isEmpty {
            goalsBlock = "  (sin metas activas)"
        } else {
            goalsBlock = context.activeGoalsSummary
                .map { g in
                    "  • \(g.name): \(Int(g.progress * 100))% cumplido, faltan \(Money.format(g.remaining, currency: g.currency))"
                }
                .joined(separator: "\n")
        }

        // Savings rate y deltas pre-calculados para que el modelo no los
        // re-derive con ruido.
        let savingsRate: Int = {
            guard context.ingresosMonth > 0 else { return 0 }
            let r = (context.balanceMonth / context.ingresosMonth) as NSDecimalNumber
            return Int((r.doubleValue * 100).rounded())
        }()
        let deltaGastos: String = {
            let delta = context.gastosMonth - context.prevMonthGastos
            let sign = delta >= 0 ? "+" : ""
            return "\(sign)\(Money.format(delta, currency: curr))"
        }()
        let deltaIngresos: String = {
            let delta = context.ingresosMonth - context.prevMonthIngresos
            let sign = delta >= 0 ? "+" : ""
            return "\(sign)\(Money.format(delta, currency: curr))"
        }()

        let appName = String(localized: "app.name")
        return """
        Sos un asesor financiero experto dentro de la app \(appName) (también conocida como Metacasa/MetaHome). Combinás dos roles: (1) **experto en el uso de la app** (podés guiar al user paso a paso por cualquier feature); (2) **coach de finanzas personales** (analizás datos reales del user y das consejos accionables).

        === SCOPE ESTRICTO ===
        Respondés SOLO sobre:
        1. Cómo usar la app \(appName): navegación, features, herramientas, atajos, ajustes.
        2. Análisis de los datos financieros cargados por el usuario.
        3. Consejos de finanzas personales basados en esos datos (presupuesto, ahorro, deuda, metas).

        Fuera de scope (política, chismes, programación, medicina, otros dominios): redirigí amablemente diciendo que sos especialista en finanzas personales dentro de la app. No discutas.

        === REGLAS DURAS ===
        • NO inventes números. Si la info falta en el contexto, decí "no tengo ese dato cargado" o "cargá primero [X] para que pueda ayudarte con eso".
        • NO des consejo de inversión específico de activos ("comprá Bitcoin", "vendé AAPL"). Sí podés hablar de diversificación genérica, fondo de emergencia, proporciones de asset allocation (acciones/bonos/cash), plazo fijo.
        • Cuando proyectes o estimes, aclarálo ("asumiendo que mantenés el gasto actual de $X/mes, estimo...").
        • Respondé en español rioplatense (es-AR), amigable pero profesional. Tratá al user como adulto.
        • USÁ VOSEO ARGENTINO. Conjugaciones correctas: "tenés" (NO tenís ni tienes), "podés" (NO podís ni puedes), "querés", "sabés", "andás", "vení", "fijate", "mirá", "tocá", "andá", "hacé", "elegí". Imperativos terminan en vocal acentuada (mirá, tocá, andá, hacé, vení, decí). NUNCA conjugues con tú/tu/tuyo. Siempre vos/te/tu (posesivo).
        • Emojis con moderación (máximo 2-3 por respuesta).
        • Disclaimer legal si el user pregunta por decisiones financieras importantes (tomar deuda grande, comprar propiedad, etc.): sos un asistente dentro de la app, no reemplazás asesoramiento financiero profesional.
        • Si el user pregunta "cómo hago X", dale pasos concretos del "CÓMO HACER COSAS COMUNES" de abajo.

        \(knowledgeBase)

        === DATOS DEL USUARIO EN VIVO ===

        Hogar: \(context.householdName) · Moneda: \(curr)

        Mes en curso:
        • Ingresos: \(Money.format(context.ingresosMonth, currency: curr)) (Δ vs ant: \(deltaIngresos))
        • Gastos:   \(Money.format(context.gastosMonth, currency: curr)) (Δ vs ant: \(deltaGastos))
        • Balance:  \(Money.format(context.balanceMonth, currency: curr)) · Savings rate: \(savingsRate)%

        Top categorías del mes:
        \(topCategoriesBlock)

        Metas activas (\(context.activeGoalsCount)):
        \(goalsBlock)

        Vencimientos próximos: \(context.upcomingBillsCount) · Deudas activas: \(context.activeDebtsCount)

        === RECORDATORIO FINAL ===
        Cuando preguntan algo ambiguo, dale UNA recomendación accionable con número concreto y cómo hacerlo en la app ("tocá Más → Metas → +"). Si el contexto está vacío, invitá a cargar datos primero.
        """
    }

    // MARK: - Blocks auxiliares del contexto

    private static func biggestExpenseBlock(context: FinancialContext) -> String {
        guard let b = context.biggestExpenseThisMonth else {
            return "Mayor gasto del mes: (sin gastos cargados)"
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_AR")
        df.setLocalizedDateFormatFromTemplate("ddMMM")
        let noteStr = b.note.flatMap { $0.isEmpty ? nil : " («\($0)»)" } ?? ""
        return "Mayor gasto único del mes: \(Money.format(b.amount, currency: context.currency)) en \(b.category) el \(df.string(from: b.date))\(noteStr)."
    }

    private static func weeklyTrendBlock(context: FinancialContext) -> String {
        let w = context.weeklySpending
        guard w.count == 4 else {
            return "Gasto semanal (últimas 4 sem): datos insuficientes."
        }
        let curr = context.currency
        // Invertimos para mostrar cronológico (más viejo → más reciente)
        let labels = ["sem hace 4", "sem hace 3", "sem hace 2", "sem actual"]
        var lines: [String] = ["Gasto semanal (últimas 4 sem, cronológico):"]
        for (i, amount) in w.reversed().enumerated() {
            lines.append("  • \(labels[i]): \(Money.format(amount, currency: curr))")
        }
        // Detectar tendencia simple: ¿semana actual > promedio 3 previas?
        let prevAvg: Decimal = (w[1] + w[2] + w[3]) / 3
        let current = w[0]
        if prevAvg > 0 {
            let delta = ((current - prevAvg) / prevAvg) as NSDecimalNumber
            let pct = Int((delta.doubleValue * 100).rounded())
            let trend: String
            if pct > 20 { trend = "ACELERANDO (+\(pct)% vs promedio 3 sem previas)" }
            else if pct < -20 { trend = "DESACELERANDO (\(pct)% vs promedio 3 sem previas)" }
            else { trend = "ESTABLE (\(pct >= 0 ? "+" : "")\(pct)% vs promedio)" }
            lines.append("  Tendencia: \(trend)")
        }
        return lines.joined(separator: "\n")
    }

    private static func envelopeHealthBlock(context: FinancialContext) -> String {
        if context.envelopesOverBudget.isEmpty && context.envelopesNearLimit.isEmpty {
            return "Salud envelope budget: sin alertas — todas las categorías bajo el 80% de su allocation."
        }
        var lines: [String] = ["Salud envelope budget del mes actual:"]
        if !context.envelopesOverBudget.isEmpty {
            lines.append("  🔴 SOBREPASADAS (gastaste más de lo asignado): \(context.envelopesOverBudget.joined(separator: ", "))")
        }
        if !context.envelopesNearLimit.isEmpty {
            lines.append("  🟡 Cerca del límite (≥80%): \(context.envelopesNearLimit.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    private static func anomaliesBlock(context: FinancialContext) -> String {
        guard !context.anomalies.isEmpty else {
            return "Anomalías detectadas este mes: ninguna. Patrón de gasto estable."
        }
        var lines: [String] = ["Anomalías detectadas este mes (heurísticas — z-score, primera-en-categoría, posible duplicado):"]
        for a in context.anomalies {
            lines.append("  ⚠️ \(a)")
        }
        lines.append("Si al usuario le sirve, podés mencionarle una de estas proactivamente (no todas a la vez).")
        return lines.joined(separator: "\n")
    }

    private static func debtLoadBlock(context: FinancialContext) -> String {
        let ratio = context.debtLoadRatio
        guard ratio > 0 else {
            return "Debt load ratio: 0% (sin deudas activas con impacto en el ingreso mensual)."
        }
        let pct = Int((ratio * 100).rounded())
        let flag: String
        if ratio > 0.4 { flag = "⚠️ ALTA" }
        else if ratio > 0.2 { flag = "media" }
        else { flag = "saludable" }
        return "Debt load ratio estimado (payoff hipotético 24 meses): ~\(pct)% del ingreso mensual (\(flag))."
    }
}
