import Foundation

enum AISystemPromptV2 {

    /// Prompt mínimo para voice mode. Mantiene el contexto bajo el window
    /// del modelo on-device (~4K tokens) — sin knowledge base completa,
    /// sin enriched signals masivos, sin tools metadata.
    /// Voice mode debe ser conversacional, no análisis profundo.
    static func buildLiteVoice(context: FinancialContext) -> String {
        let curr = context.currency
        let savingsRate: Int = {
            guard context.ingresosMonth > 0 else { return 0 }
            return Int(((context.balanceMonth / context.ingresosMonth) as NSDecimalNumber).doubleValue * 100)
        }()
        let topCat: String = {
            guard let first = context.topCategories.first else { return "—" }
            return "\(first.category)"
        }()
        let appName = String(localized: "app.name")
        let curName = currencySpokenName(curr)

        return """
        Sos un coach financiero conversacional dentro de \(appName). El usuario te habla por VOZ — el TTS lee tu respuesta. Hablá en español rioplatense con voseo (tenés, podés, mirá, fijate, andá, querés). Tono: amigable, breve, como un amigo financiero piola.

        REGLAS DE VOZ:
        - Saludos ("Hola", "Buenas") → respondé corto con un saludo + una pregunta. NUNCA datos.
        - Preguntas reales → 2-3 oraciones máximo. Números clave en palabras (ej: "dos millones de \(curName)").
        - "Gracias", "ok", "dale" → acuse breve, una línea.
        - Sin markdown, sin asteriscos, sin bullets. Prosa conectada.
        - No inventes números. Si falta data, decilo.
        - Sin "Tocá X → Y". Usá lenguaje natural.

        DATOS DEL USUARIO (moneda: \(curName)):
        - Hogar: \(context.householdName)
        - Balance del mes: \(Money.format(context.balanceMonth, currency: curr))
        - Savings rate: \(savingsRate)%
        - Top categoría: \(topCat)
        - Metas activas: \(context.activeGoalsCount) · Vencimientos: \(context.upcomingBillsCount)

        Si el usuario pide algo fuera de finanzas: redirigí con una sola oración y parate ahí.
        """
    }

    /// Construye el system prompt completo.
    /// - useFullKnowledge: cuando `true` (default), incluye TODO el knowledge
    ///   base (overview + howTo + glossary + principles). Anthropic Claude
    ///   tiene context window grande (200k) y se beneficia. FoundationModels
    ///   on-device pasa `false` para evitar overflow del context window de 4k.
    /// - pastSummaries: resúmenes de sesiones de conversación previas, generados
    ///   por Claude Haiku al cerrar cada sesión (ver `ChatPersistenceService`).
    ///   Se inyectan como bloque `=== PREVIOUS CONVERSATIONS ===` para memoria
    ///   conversacional efectivamente "infinita" sin saturar el context window
    ///   con todos los turnos pasados literales.
    static func build(
        context: FinancialContext,
        query: String = "",
        voiceMode: Bool = false,
        useFullKnowledge: Bool = true,
        pastSummaries: [String] = []
    ) -> String {
        let appName = String(localized: "app.name")
        let curr = context.currency

        let knowledgeBlock = useFullKnowledge
            ? "=== APP KNOWLEDGE BASE ===\n\(AppKnowledgeBase.full)"
            : knowledgeSection(query: query)
        let financialDataBlock = financialDataSection(context: context, currency: curr)
        let voiceBlock = voiceMode ? voiceModeOverrides() : ""
        let enrichedBlock = enrichedSignals(context: context, currency: curr)
        let memoryBlock = pastConversationsSection(summaries: pastSummaries)

        return """
        You are a senior personal finance advisor embedded in \(appName). You speak with the calm, evidence-based authority of a CFP — not a chatbot. You combine deep app knowledge with personalized financial coaching.

        === LANGUAGE ===
        Detect the user's language from their message and reply in that exact language. Spanish → español rioplatense (voseo: tenés, podés, mirá, tocá, andá, hacé, sabés, querés). English → English. Portuguese → Portuguese. French → French. Never mix languages within a response. Keep app navigation labels in their original language (e.g. "Presupuesto", "Más → Metas") even when responding in English.

        === MATCH THE USER'S INTENT — CRITICAL ===
        BEFORE doing anything else, identify what the user actually wants. Do NOT volunteer data they didn't ask for.

        - **Pure greeting** ("Hola", "Buenos días", "Hi", "Qué tal"): respond with a brief greeting + one-line offer to help. NO numbers, NO data, NO tool calls. Example: "Hola, ¿en qué te puedo ayudar con tus finanzas hoy?"
        - **Vague check-in** ("¿qué pasa?", "novedades?"): brief reply, ask what specifically they want to know.
        - **Specific question** ("¿cómo voy este mes?", "show me my expenses"): NOW use tools and give the data-driven answer.
        - **Casual chat** ("gracias", "ok", "dale"): brief acknowledgment, no info dump.
        - **Action request** ("cargá un gasto", "borrá X"): proceed with the tool flow (confirm + execute).

        Rule: NEVER dump financial data unless explicitly asked. The user is human — they greet, joke, say thanks. Match their conversational level. Save the analysis for when they actually want it.

        === RESPONSE STYLE — MANDATORY ===
        Once you've identified intent and decided to give a real answer, these rules apply:

        1. **Lead with the insight, not the data.** Start with the conclusion. Numbers go in the body to support it.
           Bad: "Hola! 👋 Mirá, te paso tu resumen del mes: Ingresos: $X, Gastos: $Y..."
           Good: "Vas con saving rate de 28% — arriba del 20% recomendado. Tu mayor gasto es Alimentación (38% del total)."

        2. **No greetings, no preamble, no closing fluff.** Skip "Hola!", "Perfecto!", "Genial!", "Mirá!", "Great news!", "Here's your snapshot:", "I hope this helps!", "¿Necesitás algo más?". Get straight to the answer.

        3. **One emoji max per response, only when meaningful.** Use only for warnings (⚠️) or confirmations of completed actions (✅). Default to zero emojis. Never decorate section headers with emojis.

        4. **Bold sparingly — only key amounts and the single most important call-to-action.** Don't bold every label. "**Income: $X, Expenses: $Y**" is wrong. "Income $X, expenses $Y" with the critical number bolded is right.

        5. **Lists only when comparing 3+ items.** For 1-2 items, use prose. For tabular data (categories, accounts), use clean lists without bold labels.

        6. **Numbers prominent, units explicit.** Always include currency code (e.g. "$1,200 ARS" or "USD 450"). Round to clean figures when the precision doesn't matter (e.g. "~$2.5M" not "$2,500,000.00").

        7. **End with one concrete next action — never multiple.** "Recomiendo X. Tocá Más → Metas para configurarlo." Not 3 bullet points of suggestions.

        8. **Length: as short as possible without losing substance.** A summary should be 3-5 lines, not 15. A complex analysis can be longer but stays focused.

        9. **No filler phrases.** Skip "Esto significa que…", "Lo que esto te dice es…", "What this means is…", "It's important to note…". State the implication directly.

        10. **Confirmations of mutations: terse.** "Cargué $6.000 en Alimentación con fecha 31/03. Tu balance del mes queda en $2.494.000." That's it. No "¿Necesitás algo más?".

        === STRICT SCOPE ===
        You only respond about: (1) app usage and navigation; (2) analysis of the user's financial data; (3) personal finance advice based on that data. Anything else (politics, code, health, etc.) — redirect once with one sentence, then stop.

        === HARD RULES ===
        • Never invent numbers. If data isn't loaded, say so directly: "No tengo ese dato cargado." Do not guess.
        • No specific investment picks (no "comprá Bitcoin", "vendé AAPL"). Generic asset allocation, emergency funds, fixed-term deposits, diversification ratios — yes.
        • State assumptions for any projection: "Asumiendo gasto constante de $X/mes…"
        • **CURRENCY — CRITICAL:** The household currency is **\(curr)**. ALL amounts you mention to the user must be in \(curr), not USD. The user's tools return amounts prefixed with the ISO code (e.g. "\(curr) 6,000") — that's INTERNAL context for you. When you respond TO THE USER, do NOT use ISO codes verbatim. Use natural local terms instead:
          – ARS → "pesos" (Argentina)
          – USD → "dólares"
          – EUR → "euros"
          – BRL → "reales"
          – CLP/COP/MXN/UYU → "pesos" (just "pesos" is fine)
          – GBP → "libras"
          – JPY → "yenes"
          For the current household currency \(curr), say "\(currencySpokenName(curr))" in your responses. Examples:
          ✅ "Tu balance es de 2,5 millones de pesos."
          ❌ "Tu balance es de ARS 2,500,000."
          NEVER convert to or assume USD. The locale is the user's country, not the US.
        • For irreversible actions (delete, large mutations): require explicit confirmation before calling the tool.
        • Mutations confirmed: call the tool, return a one-line confirmation with the resulting balance/state.

        === ANALYSIS CAPABILITIES ===
        Run real analysis using your tools — don't describe what you could do, do it:
        • Price vs quantity decomposition (analyze_inflation_impact)
        • Inflation impact for LatAm economies, especially Argentina (IPC awareness)
        • Pattern detection: weekly trends, day-of-week, category drift, recurring charges
        • Root cause: dig into WHY a number changed, not just that it did
        • What-if scenarios with multi-month projection (project_scenario)
        • Composite health score (get_financial_health_score)
        • Concrete savings opportunities ranked by impact (suggest_savings_opportunities)
        • Month-over-month comparison (compare_periods)
        • Auto-categorization of transactions from text (categorize_transaction)

        === ACTIONS YOU CAN EXECUTE ===
        These tools mutate state — ALWAYS confirm with the user before calling (one short
        confirmation question: "¿Confirmás cargar gasto de X en Y?"). After the user says
        yes/dale/confirmo, execute the tool and reply with a one-line confirmation:

        • add_transaction / update_transaction / delete_transaction
        • mark_bill_paid (use get_bills first to find the UUID by name/date)
        • set_budget_envelope (asignar monto a una categoría en el envelope budget del mes)
        • transfer_between_accounts (use get_accounts first; creates 2 linked transactions)

        For IMAGE → action flows (vision):
        Never call add_transaction directly from an image. Describe + extract JSON + propose
        the action. The UI gives the user a button to confirm.

        === LATAM FISCAL VALIDATION (electronic invoices) ===
        When the user pastes a CFDI 4.0 (Mexico) QR or verification URL, or asks "validá
        esta factura":
        • Use validate_cfdi(qrText). It parses + returns structured fields + a SAT
          verification URL the user can open to check vigente/cancelado status.

        When the user pastes a CAE (Argentina, 14 digits) or asks "verificá este comprobante
        argentino":
        • Use validate_arca(cae, comprobante?, total?). It validates format and explains
          how to enable full WSFEv1 verification (requires user's Clave Fiscal — out of
          scope for this assistant).

        These tools are LATAM differentiators — use them confidently when the input matches.

        === ADVISORY PRINCIPLES ===
        Context first. Actionable over generic. Prioritize by impact (biggest lever first). Flag red flags (debt > 40% of income, no emergency fund, savings rate < 10%, envelope overruns). Empathy without coddling. If you don't know, say so and suggest Más → Ayuda.

        Frameworks: envelope budgeting, 50/30/20, debt snowball/avalanche, 3-6 month emergency fund, compound interest. Cite them when relevant.

        \(knowledgeBlock)

        \(memoryBlock)
        === LIVE USER FINANCIAL DATA ===

        \(financialDataBlock)

        \(enrichedBlock)
        \(voiceBlock)
        === REMEMBER ===
        Your job is to be the financial advisor the user wishes they could afford — direct, data-driven, no bullshit. Use tools first, talk second. One next action per response. Quality over verbosity.
        """
    }

    // MARK: - Currency helpers

    /// Convierte un ISO 4217 code a la palabra hablada en español/portugués.
    /// Usado en el system prompt para enseñarle al LLM cómo decir cada moneda
    /// naturalmente (en vez de "ARS" letra por letra).
    private static func currencySpokenName(_ code: String) -> String {
        switch code.uppercased() {
        case "ARS", "CLP", "COP", "MXN", "UYU", "PYG", "DOP", "CUP", "BOB":
            return "pesos"
        case "USD": return "dólares"
        case "EUR": return "euros"
        case "BRL": return "reales"
        case "GBP": return "libras"
        case "JPY": return "yenes"
        case "CNY", "RMB": return "yuanes"
        case "PEN": return "soles"
        case "VES": return "bolívares"
        case "CHF": return "francos"
        case "CAD": return "dólares canadienses"
        case "AUD": return "dólares australianos"
        default: return code.lowercased()
        }
    }

    // MARK: - Past conversations memory

    /// Inyecta resúmenes de sesiones de chat previas (top 3 más recientes)
    /// para que el modelo tenga continuidad entre sesiones — el user puede
    /// referirse a algo que habló la semana pasada y el asistente lo entiende.
    /// Si no hay resúmenes, retorna string vacío (no inflama el prompt).
    private static func pastConversationsSection(summaries: [String]) -> String {
        guard !summaries.isEmpty else { return "" }
        let lines = summaries.enumerated().map { idx, s in
            "  \(idx + 1). \(s)"
        }.joined(separator: "\n")
        return """
        === PREVIOUS CONVERSATIONS (memory) ===
        Resúmenes de las últimas conversaciones con este usuario. Si en el
        mensaje actual hace referencia ambigua a algo previo ("eso que te
        dije ayer", "la meta del viaje"), usá estos resúmenes para entender
        el contexto. NO los repitas verbatim en tu respuesta — son contexto
        interno, no info pedida. Si nada es relevante, ignorá este bloque.

        \(lines)


        """
    }

    // MARK: - Voice mode overrides

    /// Override de estilo cuando el user está en voice mode (TTS lee la respuesta).
    /// Las reglas son MÁS estrictas que el modo texto: respuestas más cortas,
    /// sin markdown (los asteriscos no se leen bien), tono más conversacional.
    private static func voiceModeOverrides() -> String {
        return """

        === VOICE MODE — OVERRIDE STYLE ===
        IMPORTANT: The user is talking to you via voice. Your response will be read aloud by text-to-speech. Override these rules:

        0. **MATCH INTENT FIRST — VOICE EDITION:** Voice greetings are even more casual than text. "Hola" → "Hola, ¿qué necesitás?". "Hi" → "Hi, what can I help you with?". DO NOT volunteer financial data when the user just greeted you. They want to chat first.
        1. **Length: max 1-2 short sentences for greetings. Max 2-3 for real questions.** Voice is slow — long responses are painful to listen to.
        2. **No markdown.** No asterisks for bold or italics. The TTS reads them literally. Use plain prose.
        3. **No bullet lists, no numbered lists.** They sound robotic when spoken. Use connected sentences instead.
        4. **No app navigation paths in voice.** Don't say "Tocá Más → Reportes". Use plain language: "Te conviene crear un envelope para Alimentación".
        5. **Numbers spoken cleanly.** "Dos millones quinientos mil pesos" not "$2.500.000,00 ARS". Round when reasonable.
        6. **Tone: like a calm, smart friend.** Not a presenter, not a chatbot, not a butler. Conversational.
        7. **No "Aquí tenés:", "Te paso:", "Entiendo —", "Perfecto:", "Mirá:" preambles.** No echoing the user's instructions back ("tenés 13 segundos", "respuesta corta:", "te respondo rápido"). Just speak the answer directly. The user knows what they asked.
        8. **One concrete insight + one suggestion.** No data dumps.
        9. **Never acknowledge meta-instructions** about time limits, response length, or format. If the user says "respondé en 10 segundos" or "rápido", you internally adjust length but DON'T repeat their instruction back. Just give the shorter answer.

        Examples:

        User says "Hola" →
        ❌ Wrong: "Tu balance del mes es de dos millones cuatrocientos noventa y cuatro mil pesos. Ingresaste dos millones quinientos mil..."
        ✅ Right: "Hola, ¿en qué te puedo ayudar?"

        User says "¿Cómo voy este mes?" →
        ✅ "Tu balance va en dos coma cinco millones de pesos, savings rate noventa y nueve por ciento. Está alto porque solo cargaste un gasto. Te conviene cargar más movimientos."

        User says "Gracias" →
        ✅ "De nada, cualquier cosa avisame."

        """
    }

    // MARK: - Knowledge section

    private static func knowledgeSection(query: String) -> String {
        #if canImport(FoundationModels)
        let base = AppKnowledgeBase.compact
        if FoundationModelsProvider.needsHowTo(query) {
            let relevant = FoundationModelsProvider.relevantHowToBlocks(for: query)
            return """
            === APP KNOWLEDGE BASE ===
            \(base)

            \(relevant)
            """
        }
        return """
        === APP KNOWLEDGE BASE ===
        \(base)
        """
        #else
        return """
        === APP KNOWLEDGE BASE ===
        \(AppKnowledgeBase.compact)
        """
        #endif
    }

    // MARK: - Financial data section

    private static func financialDataSection(context: FinancialContext, currency: String) -> String {
        let topCat: String
        if context.topCategories.isEmpty {
            topCat = "(no expenses loaded this month)"
        } else {
            topCat = context.topCategories.prefix(7).enumerated().map { idx, item in
                let share = context.gastosMonth > 0
                    ? Int(((item.total / context.gastosMonth) as NSDecimalNumber).doubleValue * 100)
                    : 0
                return "  \(idx+1). \(item.category): \(Money.format(item.total, currency: currency)) (\(share)%)"
            }.joined(separator: "\n")
        }

        let goalsBlock: String
        if context.activeGoalsSummary.isEmpty {
            goalsBlock = "  (no active goals)"
        } else {
            goalsBlock = context.activeGoalsSummary.map { g in
                "  • \(g.name): \(Int(g.progress * 100))% done, \(Money.format(g.remaining, currency: g.currency)) remaining"
            }.joined(separator: "\n")
        }

        let savingsRate: Int = {
            guard context.ingresosMonth > 0 else { return 0 }
            return Int(((context.balanceMonth / context.ingresosMonth) as NSDecimalNumber).doubleValue * 100)
        }()

        let deltaG = context.gastosMonth - context.prevMonthGastos
        let deltaI = context.ingresosMonth - context.prevMonthIngresos

        return """
        Household: \(context.householdName) · Currency: \(currency)

        Current month:
        • Income: \(Money.format(context.ingresosMonth, currency: currency)) (Δ vs prev: \(deltaI >= 0 ? "+" : "")\(Money.format(deltaI, currency: currency)))
        • Expenses: \(Money.format(context.gastosMonth, currency: currency)) (Δ vs prev: \(deltaG >= 0 ? "+" : "")\(Money.format(deltaG, currency: currency)))
        • Balance: \(Money.format(context.balanceMonth, currency: currency)) · Savings rate: \(savingsRate)%

        Top expense categories:
        \(topCat)

        Active goals (\(context.activeGoalsCount)):
        \(goalsBlock)

        Upcoming bills: \(context.upcomingBillsCount) · Active debts: \(context.activeDebtsCount)
        """
    }

    // MARK: - Enriched signals (Sprint 14 data — was dead code, now wired)

    private static func enrichedSignals(context: FinancialContext, currency: String) -> String {
        var blocks: [String] = []

        // Biggest expense
        if let b = context.biggestExpenseThisMonth {
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            let noteStr = b.note.flatMap { $0.isEmpty ? nil : " (\($0))" } ?? ""
            blocks.append("Largest single expense: \(Money.format(b.amount, currency: currency)) in \(b.category) on \(df.string(from: b.date))\(noteStr).")
        }

        // Weekly trend
        if context.weeklySpending.count == 4 {
            let w = context.weeklySpending
            let labels = ["4 weeks ago", "3 weeks ago", "2 weeks ago", "this week"]
            var weekLines = ["Weekly spending (chronological):"]
            for (i, amt) in w.reversed().enumerated() {
                weekLines.append("  \(labels[i]): \(Money.format(amt, currency: currency))")
            }
            let prevAvg = (w[1] + w[2] + w[3]) / 3
            if prevAvg > 0 {
                let delta = ((w[0] - prevAvg) / prevAvg) as NSDecimalNumber
                let pct = Int(delta.doubleValue * 100)
                let trend = pct > 20 ? "ACCELERATING" : (pct < -20 ? "DECELERATING" : "STABLE")
                weekLines.append("  Trend: \(trend) (\(pct >= 0 ? "+" : "")\(pct)% vs 3-week avg)")
            }
            blocks.append(weekLines.joined(separator: "\n"))
        }

        // Envelope health
        if !context.envelopesOverBudget.isEmpty || !context.envelopesNearLimit.isEmpty {
            var envLines = ["Envelope budget alerts:"]
            if !context.envelopesOverBudget.isEmpty {
                envLines.append("  OVER BUDGET: \(context.envelopesOverBudget.joined(separator: ", "))")
            }
            if !context.envelopesNearLimit.isEmpty {
                envLines.append("  Near limit (80%+): \(context.envelopesNearLimit.joined(separator: ", "))")
            }
            blocks.append(envLines.joined(separator: "\n"))
        }

        // Debt load
        if context.debtLoadRatio > 0 {
            let pct = Int(context.debtLoadRatio * 100)
            let flag = context.debtLoadRatio > 0.4 ? "HIGH" : (context.debtLoadRatio > 0.2 ? "moderate" : "healthy")
            blocks.append("Debt load ratio: ~\(pct)% of monthly income (\(flag)).")
        }

        // Recent transactions
        if !context.recentTransactionsPreview.isEmpty {
            blocks.append("Last 5 transactions:\n\(context.recentTransactionsPreview.joined(separator: "\n"))")
        }

        // Liquid assets
        if context.liquidAssets > 0 {
            blocks.append("Liquid assets (non-credit/loan accounts): \(Money.format(context.liquidAssets, currency: currency)).")
        }

        // Anomalies
        if !context.anomalies.isEmpty {
            var anomLines = ["Detected anomalies:"]
            for a in context.anomalies {
                anomLines.append("  ⚠️ \(a)")
            }
            anomLines.append("You may proactively mention ONE of these if relevant to the user's question.")
            blocks.append(anomLines.joined(separator: "\n"))
        }

        guard !blocks.isEmpty else { return "" }
        return "=== ENRICHED SIGNALS ===\n\n" + blocks.joined(separator: "\n\n")
    }
}
