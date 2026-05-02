import Foundation

/// Dispatcher que mapea tool calls del cloud LLM a `AIToolHandler`.
///
/// Recibe el `name` de la tool + el `input` (dict JSON) y ejecuta la tool
/// correspondiente. Cuando estamos en iOS 26+ y FoundationModels está disponible,
/// usamos los tipos `Arguments` de cada tool. Como AnthropicProvider corre en
/// cualquier iOS, parseamos el input directamente sin depender de @Generable.
@MainActor
enum AnthropicToolDispatcher {

    static func dispatch(
        name: String,
        input: [String: AnyJSON],
        handler: AIToolHandler
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await dispatchOniOS26(name: name, input: input, handler: handler)
        }
        #endif
        return "Tool execution requires iOS 26+ (currently the AI tool handler is gated to FoundationModels-eligible builds)."
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func dispatchOniOS26(
        name: String,
        input: [String: AnyJSON],
        handler: AIToolHandler
    ) async throws -> String {
        switch name {
        case "query_transactions":
            let args = QueryTransactionsTool.Arguments(
                category: input["category"]?.stringValue,
                dateFrom: input["dateFrom"]?.stringValue,
                dateTo: input["dateTo"]?.stringValue,
                type: input["type"]?.stringValue,
                noteContains: input["noteContains"]?.stringValue,
                amountMin: input["amountMin"]?.doubleValue,
                amountMax: input["amountMax"]?.doubleValue,
                limit: input["limit"]?.intValue
            )
            return try await handler.queryTransactions(args)

        case "add_transaction":
            guard let type = input["type"]?.stringValue,
                  let amount = input["amount"]?.doubleValue,
                  let category = input["category"]?.stringValue else {
                return "Error: missing required field (type, amount, or category)"
            }
            let args = AddTransactionTool.Arguments(
                type: type,
                amount: amount,
                category: category,
                subcategory: input["subcategory"]?.stringValue,
                note: input["note"]?.stringValue,
                date: input["date"]?.stringValue
            )
            return try await handler.addTransaction(args)

        case "update_transaction":
            guard let id = input["transactionId"]?.stringValue else {
                return "Error: transactionId required"
            }
            let args = UpdateTransactionTool.Arguments(
                transactionId: id,
                amount: input["amount"]?.doubleValue,
                category: input["category"]?.stringValue,
                subcategory: input["subcategory"]?.stringValue,
                note: input["note"]?.stringValue,
                date: input["date"]?.stringValue,
                type: input["type"]?.stringValue
            )
            return try await handler.updateTransaction(args)

        case "delete_transaction":
            guard let id = input["transactionId"]?.stringValue else {
                return "Error: transactionId required"
            }
            return try await handler.deleteTransaction(
                DeleteTransactionTool.Arguments(transactionId: id)
            )

        case "get_financial_summary":
            return try await handler.getFinancialSummary(
                GetFinancialSummaryTool.Arguments(
                    month: input["month"]?.stringValue,
                    includeComparison: input["includeComparison"]?.boolValue
                )
            )

        case "get_budget_status":
            return try await handler.getBudgetStatus(
                GetBudgetStatusTool.Arguments(month: input["month"]?.stringValue)
            )

        case "get_net_worth":
            return try await handler.getNetWorth()

        case "get_financial_health_score":
            return try await handler.getHealthScore()

        case "project_scenario":
            guard let scenario = input["scenario"]?.stringValue else {
                return "Error: scenario description required"
            }
            return try await handler.projectScenario(
                ProjectScenarioTool.Arguments(
                    scenario: scenario,
                    category: input["category"]?.stringValue,
                    percentChange: input["percentChange"]?.doubleValue,
                    fixedAmountChange: input["fixedAmountChange"]?.doubleValue,
                    months: input["months"]?.intValue
                )
            )

        case "detect_spending_patterns":
            return try await handler.detectSpendingPatterns(
                DetectSpendingPatternsTool.Arguments(
                    monthsBack: input["monthsBack"]?.intValue,
                    category: input["category"]?.stringValue
                )
            )

        case "suggest_savings_opportunities":
            return try await handler.suggestSavings(
                SuggestSavingsTool.Arguments(
                    targetSavings: input["targetSavings"]?.doubleValue
                )
            )

        case "get_goals":
            return try await handler.getGoals(
                GetGoalsTool.Arguments(
                    includeCompleted: input["includeCompleted"]?.boolValue
                )
            )

        case "get_accounts":
            return try await handler.getAccounts(
                GetAccountsTool.Arguments(
                    includeInactive: input["includeInactive"]?.boolValue
                )
            )

        case "get_bills":
            return try await handler.getBills(
                GetBillsTool.Arguments(
                    daysAhead: input["daysAhead"]?.intValue
                )
            )

        case "analyze_inflation_impact":
            return try await handler.analyzeInflation(
                AnalyzeInflationTool.Arguments(
                    monthsBack: input["monthsBack"]?.intValue,
                    category: input["category"]?.stringValue
                )
            )

        default:
            return "Error: unknown tool '\(name)'"
        }
    }
    #endif
}
