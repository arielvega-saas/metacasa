import Foundation

/// Motor del asistente financiero de Metacasa.
///
/// **Estado actual (Sprint 2)**: provider estadístico local. Sin LLM. Responde
/// via keyword routing + cálculos determinísticos sobre el `FinancialContext`.
///
/// **Próximo paso (Sprint 3)**: reemplazar `ask(...)` por FoundationModels
/// (Apple Intelligence, iOS 26+) con el mismo contrato. El system prompt y
/// los guardrails quedan definidos en `project_metacasa_ia_architecture.md`.
///
/// **Guardrails de scope**: responde SOLO sobre la app y los datos cargados.
/// No inventa números. No da consejos de inversión específicos. No sale de
/// finanzas personales.
actor AIAssistantService {
    static let shared = AIAssistantService()
    private init() {}

    enum Intent: String, CaseIterable, Sendable {
        case summary
        case topSpending
        case suggestBudget
        case projectBalance
        case goalsHelp
        case appHelp
        case unknown
    }

    /// Match de frase con word boundaries — evita matches dentro de palabras.
    /// Ej: containsWord("porque está", "que es") → false (porque ni "que" ni
    /// "es" son palabras separadas en "porque está").
    private static func containsWord(_ text: String, phrase: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    static func detectIntent(_ message: String) -> Intent {
        let m = message.lowercased()
        if m.contains("resumen") || m.contains("cómo voy") || m.contains("como voy") || m.contains("balance del mes") || m.contains("qué tal voy") {
            return .summary
        }
        if m.contains("dónde gasto") || m.contains("donde gasto") || m.contains("mayores gastos") || m.contains("top categ") || m.contains("en qué se va") {
            return .topSpending
        }
        if m.contains("presupuesto") || m.contains("sugerí") || m.contains("sugeri") || m.contains("cuánto puedo gastar") || m.contains("cuanto puedo gastar") {
            return .suggestBudget
        }
        if m.contains("proyectá") || m.contains("proyecta") || m.contains("fin de mes") || m.contains("qué queda") || m.contains("cuánto me va") {
            return .projectBalance
        }
        if m.contains("meta") || m.contains("ahorro") || m.contains("objetivo") {
            return .goalsHelp
        }
        // "Cómo hago" / "How do I" / "Cómo funciona" — intención de aprender a usar la app.
        let appHelpPatterns = [
            "ayuda", "cómo uso", "como uso", "manual",
            "cómo hago", "como hago", "cómo puedo", "como puedo",
            "cómo funciona", "como funciona", "cómo se", "como se",
            "how do i", "how to", "how can i",
            "qué es", "que es", "qué significa", "que significa",
            "where", "dónde está", "donde esta",
            "tutorial", "guide", "guía"
        ]
        // Match con word boundaries para evitar falsos positivos
        // (ej. "porque está" no debería matchear "que es").
        if appHelpPatterns.contains(where: { Self.containsWord(m, phrase: $0) }) {
            return .appHelp
        }
        if m.contains("?") {
            // "?" solo no es señal clara — dejamos que caiga a unknown y el
            // fallback sugiera reformular. Pero si es muy corto (<10 chars),
            // tratamos como appHelp para iniciar conversación.
            if message.count < 10 {
                return .appHelp
            }
        }
        return .unknown
    }

    func ask(
        message: String,
        context: FinancialContext,
        householdId: UUID? = nil,
        userId: UUID? = nil,
        history: [ChatTurn] = [],
        voiceMode: Bool = false
    ) async -> String {
        var debugTrace: [String] = []

        // Tier 1: Apple Intelligence (FoundationModels) — on-device, free.
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let response = try await FoundationModelsProvider.ask(
                    message: message,
                    context: context,
                    householdId: householdId,
                    userId: userId
                )
                NSLog("[AI] Tier 1 (FoundationModels) success")
                return response
            } catch {
                let msg = "Tier 1 (FoundationModels): \(error.localizedDescription)"
                NSLog("[AI] %@", msg)
                debugTrace.append(msg)
            }
        }
        #endif

        // Tier 2: Cloud LLM (Claude Haiku 4.5 via Edge Function).
        guard let hid = householdId else {
            debugTrace.append("Tier 2 skipped: no householdId")
            return debugWrap(debugTrace, fallback: statisticalFallback(message: message, context: context))
        }
        guard let uid = userId else {
            debugTrace.append("Tier 2 skipped: no userId")
            return debugWrap(debugTrace, fallback: statisticalFallback(message: message, context: context))
        }
        guard let accessToken = await TokenHolder.shared.get() else {
            debugTrace.append("Tier 2 skipped: no accessToken in TokenHolder")
            return debugWrap(debugTrace, fallback: statisticalFallback(message: message, context: context))
        }

        do {
            let response = try await AnthropicProvider.shared.respond(
                message: message,
                context: context,
                householdId: hid,
                userId: uid,
                accessToken: accessToken,
                history: history,
                voiceMode: voiceMode
            )
            NSLog("[AI] Tier 2 (Anthropic Cloud) success")
            return response
        } catch let error as AnthropicProvider.AnthropicError {
            let msg = "Tier 2 (Anthropic): \(error.localizedDescription)"
            NSLog("[AI] %@", msg)
            debugTrace.append(msg)
        } catch let urlError as URLError {
            let msg = "Tier 2 (Anthropic) network error: \(urlError.code.rawValue) — \(urlError.localizedDescription)"
            NSLog("[AI] %@", msg)
            debugTrace.append(msg)
        } catch let decodingError as DecodingError {
            let msg = "Tier 2 (Anthropic) decoding error: \(String(describing: decodingError))"
            NSLog("[AI] %@", msg)
            debugTrace.append(msg)
        } catch {
            let msg = "Tier 2 (Anthropic) unexpected: \(type(of: error)) — \(error.localizedDescription)"
            NSLog("[AI] %@", msg)
            debugTrace.append(msg)
        }

        return debugWrap(debugTrace, fallback: statisticalFallback(message: message, context: context))
    }

    private func debugWrap(_ trace: [String], fallback: String) -> String {
        #if DEBUG
        guard !trace.isEmpty else { return fallback }
        let traceBlock = "🔍 [DEBUG TIER FLOW]\n" + trace.map { "  • \($0)" }.joined(separator: "\n")
        return "\(traceBlock)\n\n— motor estadístico —\n\n\(fallback)"
        #else
        return fallback
        #endif
    }

    /// Motor estadístico determinístico (Tier 3). Funciona offline, sin LLM,
    /// con templates basados en intent detection.
    private func statisticalFallback(message: String, context: FinancialContext) -> String {
        let intent = Self.detectIntent(message)
        switch intent {
        case .summary:        return summary(context: context)
        case .topSpending:    return topSpending(context: context)
        case .suggestBudget:  return suggestBudget(context: context)
        case .projectBalance: return projectBalance(context: context)
        case .goalsHelp:      return goalsHelp(context: context)
        case .appHelp:        return appHelp()
        case .unknown:        return fallback()
        }
    }

    // MARK: - Intents

    private func summary(context: FinancialContext) -> String {
        let curr = context.currency
        guard context.ingresosMonth > 0 || context.gastosMonth > 0 else {
            return "No tenés movimientos cargados este mes. Tocá el **+** central para registrar el primero."
        }

        let savingsRate: Int = context.ingresosMonth > 0
            ? Int(((context.balanceMonth / context.ingresosMonth) as NSDecimalNumber).doubleValue * 100)
            : 0

        let delta = context.balanceMonth - context.balancePrevMonth
        let trend: String
        if abs((delta as NSDecimalNumber).doubleValue) < 1 {
            trend = "estable vs el mes anterior"
        } else if delta > 0 {
            trend = "**\(Money.format(delta, currency: curr))** mejor que el mes anterior"
        } else {
            trend = "**\(Money.format(abs(delta), currency: curr))** peor que el mes anterior"
        }

        var lines: [String] = []
        lines.append("Balance del mes: **\(Money.format(context.balanceMonth, currency: curr))** · savings rate \(savingsRate)%.")
        lines.append("Ingresos \(Money.format(context.ingresosMonth, currency: curr)), gastos \(Money.format(context.gastosMonth, currency: curr)) — \(trend).")

        var alerts: [String] = []
        if context.upcomingBillsCount > 0 {
            alerts.append("\(context.upcomingBillsCount) vencimiento\(context.upcomingBillsCount == 1 ? "" : "s") próximo\(context.upcomingBillsCount == 1 ? "" : "s")")
        }
        if context.activeDebtsCount > 0 {
            alerts.append("\(context.activeDebtsCount) deuda\(context.activeDebtsCount == 1 ? "" : "s") activa\(context.activeDebtsCount == 1 ? "" : "s")")
        }
        if !alerts.isEmpty {
            lines.append(alerts.joined(separator: ", ").capitalizedFirst() + ".")
        }

        return lines.joined(separator: "\n\n")
    }

    private func topSpending(context: FinancialContext) -> String {
        let curr = context.currency
        guard !context.topCategories.isEmpty, context.gastosMonth > 0 else {
            return "Sin gastos cargados este mes. Tocá el **+** central para registrar el primero."
        }

        let top = context.topCategories.first!
        let topPct = Int(((top.total / context.gastosMonth) as NSDecimalNumber).doubleValue * 100)

        var lines: [String] = []
        lines.append("Tu mayor gasto: **\(top.category)** con \(Money.format(top.total, currency: curr)) (\(topPct)% del total). Es la primera palanca para reducir.")

        if context.topCategories.count > 1 {
            lines.append("")
            lines.append("Resto del top 5:")
            for (i, item) in context.topCategories.dropFirst().prefix(4).enumerated() {
                let pct = Int(((item.total / context.gastosMonth) as NSDecimalNumber).doubleValue * 100)
                lines.append("\(i + 2). \(item.category) — \(Money.format(item.total, currency: curr)) (\(pct)%)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func suggestBudget(context: FinancialContext) -> String {
        let curr = context.currency
        guard context.gastosMonth > 0 || context.prevMonthGastos > 0 else {
            return "Necesito al menos un mes de gastos cargados para sugerir un presupuesto. Cargá movimientos y volvé a preguntarme."
        }
        let avg: Decimal = (context.gastosMonth + context.prevMonthGastos) / 2

        var lines: [String] = []
        lines.append("Promedio de gasto en los últimos 2 meses: **\(Money.format(avg, currency: curr))**. Te propongo este presupuesto con buffer de 5%:")
        lines.append("")

        for item in context.topCategories.prefix(8) {
            let suggested: Decimal = item.total * 105 / 100
            lines.append("\(item.category) — \(Money.format(suggested, currency: curr))")
        }

        lines.append("")
        lines.append("Cargá estos valores en **Presupuesto** como envelopes del mes y vas a ver alertas cuando te acerques al límite.")

        return lines.joined(separator: "\n")
    }

    private func projectBalance(context: FinancialContext) -> String {
        let curr = context.currency
        let cal = Calendar.current
        let now = Date()
        let day = cal.component(.day, from: now)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let remainingDays = max(0, daysInMonth - day)

        guard day > 0, context.gastosMonth > 0 else {
            return "Sin gastos suficientes este mes para proyectar. Cargá unos días más de movimientos."
        }

        let dailyRate = context.gastosMonth / Decimal(day)
        let projectedRemaining = dailyRate * Decimal(remainingDays)
        let projectedExpenses = context.gastosMonth + projectedRemaining
        let projectedBalance = context.ingresosMonth - projectedExpenses

        let signal: String
        if (projectedBalance as NSDecimalNumber).doubleValue >= 0 {
            signal = "Balance proyectado positivo: **\(Money.format(projectedBalance, currency: curr))**."
        } else {
            signal = "⚠️ Balance proyectado **negativo**: \(Money.format(projectedBalance, currency: curr)). Vas a gastar más de lo que entra."
        }

        var lines: [String] = []
        lines.append(signal)
        lines.append("")
        lines.append("Día \(day) de \(daysInMonth). Ritmo \(Money.format(dailyRate, currency: curr))/día = \(Money.format(projectedExpenses, currency: curr)) de gasto total proyectado.")
        lines.append("")
        lines.append("Asume gasto constante. No incluye vencimientos pendientes ni compras grandes.")

        return lines.joined(separator: "\n")
    }

    private func goalsHelp(context: FinancialContext) -> String {
        guard !context.activeGoalsSummary.isEmpty else {
            return "No tenés metas activas. Creá una en **Más → Metas**: definí monto objetivo, fecha y contribución mensual. Después te ayudo a ver si vas en camino."
        }

        var lines: [String] = []
        for goal in context.activeGoalsSummary {
            let pct = Int(goal.progress * 100)
            lines.append("**\(goal.name)** — \(pct)% cumplido, faltan \(Money.format(goal.remaining, currency: goal.currency))")
        }
        lines.append("")
        lines.append("Para acelerar: identificá tu mayor categoría de gasto, reducí 10-15%, y asigná ese diferencial a la meta más prioritaria.")

        return lines.joined(separator: "\n")
    }

    private func appHelp() -> String {
        let appName = String(localized: "app.name")
        return """
        Soy tu asesor financiero dentro de \(appName). Te ayudo con análisis de tus datos y a usar la app.

        **Análisis sobre tus finanzas:**
        • Resumen del mes — "¿Cómo voy este mes?"
        • Top categorías — "¿Dónde gasto más?"
        • Presupuesto sugerido — "Hacé un presupuesto"
        • Proyección de balance — "¿Cuánto me va a quedar?"
        • Metas — "¿Cómo voy con mis metas?"
        • Salud financiera — "¿Cuál es mi health score?"

        **Cómo usar la app:**
        • "¿Cómo cargo una transacción?"
        • "¿Cómo funciona el envelope budget?"
        • "¿Cómo invito a alguien al hogar?"
        • "¿Cómo hago backup?"

        **Accesos rápidos:**
        Transacción nueva → **+** central del tab bar.
        Presupuesto del mes → tab **Presupuesto**.
        Reportes (Health Score, Pareto, 6 meses) → **Más → Reportes**.
        Backup JSON → **Ajustes → Datos → Backup**.

        Preguntame en lenguaje natural — te respondo con tus datos reales y pasos concretos.
        """
    }

    private func fallback() -> String {
        return """
        No tengo una respuesta clara para eso. Mi especialidad son tus finanzas en Metacasa.

        Probá: "¿Cómo voy este mes?", "¿Dónde gasto más?", "Hacé un presupuesto", o escribí **ayuda** para el menú completo.
        """
    }
}

// MARK: - String helper

private extension String {
    func capitalizedFirst() -> String {
        guard let first = self.first else { return self }
        return first.uppercased() + self.dropFirst()
    }
}
