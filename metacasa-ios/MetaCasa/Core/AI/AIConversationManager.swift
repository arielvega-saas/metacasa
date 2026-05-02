import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

actor AIConversationManager {
    static let shared = AIConversationManager()
    private init() {}

    private static let maxTurns = 10
    private static let maxSessionAge: TimeInterval = 600

    #if canImport(FoundationModels)
    private var _activeSession: Any?
    private var sessionCreatedAt: Date?
    private var turnCount: Int = 0
    private var lastHouseholdId: UUID?

    @available(iOS 26.0, *)
    private var activeSession: LanguageModelSession? {
        get { _activeSession as? LanguageModelSession }
        set { _activeSession = newValue }
    }
    #endif

    struct ConversationMemory: Sendable {
        var summaries: [String] = []
        static let maxSummaries = 5
    }
    private var memory = ConversationMemory()

    // MARK: - Public API

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    func respond(
        to message: String,
        context: FinancialContext,
        householdId: UUID,
        userId: UUID
    ) async throws -> String {
        let session = try await getOrCreateSession(
            context: context,
            householdId: householdId,
            userId: userId,
            query: message
        )

        let response = try await session.respond(to: message)
        turnCount += 1

        if turnCount > 3 && turnCount.isMultiple(of: 3) {
            let summary = String(response.content.prefix(200))
            addMemory(summary)
        }

        return response.content
    }
    #endif

    func reset() {
        #if canImport(FoundationModels)
        _activeSession = nil
        sessionCreatedAt = nil
        turnCount = 0
        lastHouseholdId = nil
        #endif
    }

    func clearMemory() {
        memory = ConversationMemory()
    }

    // MARK: - Session management

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func getOrCreateSession(
        context: FinancialContext,
        householdId: UUID,
        userId: UUID,
        query: String
    ) async throws -> LanguageModelSession {
        if let session = activeSession, shouldReuseSession(householdId: householdId) {
            return session
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FoundationModelsProvider.FMError.modelUnavailable(
                reason: FoundationModelsProvider.describeAvailability(model.availability)
            )
        }

        let prompt = buildPromptWithMemory(context: context, query: query)
        let handler = await AIToolHandler(
            householdId: householdId,
            userId: userId,
            currency: context.currency
        )

        let tools = buildToolset(handler: handler)
        let session = LanguageModelSession(
            model: model,
            tools: tools,
            instructions: Instructions(prompt)
        )

        activeSession = session
        sessionCreatedAt = Date()
        turnCount = 0
        lastHouseholdId = householdId

        return session
    }

    @available(iOS 26.0, *)
    private func shouldReuseSession(householdId: UUID) -> Bool {
        guard let created = sessionCreatedAt,
              let lastHid = lastHouseholdId else { return false }
        let age = Date().timeIntervalSince(created)
        return age < Self.maxSessionAge
            && turnCount < Self.maxTurns
            && lastHid == householdId
    }

    /// Expone el toolset para el streaming flow de FoundationModelsProvider.
    @available(iOS 26.0, *)
    func buildToolsForStreaming(handler: AIToolHandler) -> [any Tool] {
        buildToolset(handler: handler)
    }

    @available(iOS 26.0, *)
    private func buildToolset(handler: AIToolHandler) -> [any Tool] {
        [
            QueryTransactionsTool(handler: handler),
            AddTransactionTool(handler: handler),
            UpdateTransactionTool(handler: handler),
            DeleteTransactionTool(handler: handler),
            GetFinancialSummaryTool(handler: handler),
            GetBudgetStatusTool(handler: handler),
            GetNetWorthTool(handler: handler),
            GetHealthScoreTool(handler: handler),
            ProjectScenarioTool(handler: handler),
            DetectSpendingPatternsTool(handler: handler),
            SuggestSavingsTool(handler: handler),
            GetGoalsTool(handler: handler),
            GetAccountsTool(handler: handler),
            GetBillsTool(handler: handler),
            AnalyzeInflationTool(handler: handler),
        ]
    }
    #endif

    // MARK: - Memory

    private func buildPromptWithMemory(context: FinancialContext, query: String) -> String {
        var prompt = AISystemPromptV2.build(context: context, query: query)

        if !memory.summaries.isEmpty {
            prompt += "\n\n=== CONVERSATION MEMORY ===\n"
            prompt += "Previous conversation highlights (most recent first):\n"
            for (i, s) in memory.summaries.reversed().enumerated() {
                prompt += "  \(i+1). \(s)\n"
            }
        }

        return prompt
    }

    private func addMemory(_ summary: String) {
        memory.summaries.append(summary)
        if memory.summaries.count > ConversationMemory.maxSummaries {
            memory.summaries.removeFirst()
        }
    }
}
