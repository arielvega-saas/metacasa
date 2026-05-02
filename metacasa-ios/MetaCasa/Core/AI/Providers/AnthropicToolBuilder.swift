import Foundation

/// Constructor de tools en formato Anthropic API.
///
/// Anthropic Claude usa un schema JSON propio (subset de JSONSchema) para
/// definir las tools. Replicamos las 15 tools de FoundationModels acá pero
/// con esta sintaxis.
///
/// Mantener en sync con `AIToolDefinitions.swift` (lado FoundationModels).
enum AnthropicToolBuilder {

    static func allTools() -> [APITool] {
        [
            queryTransactions(),
            addTransaction(),
            updateTransaction(),
            deleteTransaction(),
            getFinancialSummary(),
            getBudgetStatus(),
            getNetWorth(),
            getHealthScore(),
            projectScenario(),
            detectSpendingPatterns(),
            suggestSavings(),
            getGoals(),
            getAccounts(),
            getBills(),
            analyzeInflation(),
        ]
    }

    // MARK: - Schema helpers

    private static func obj(_ pairs: [(String, AnyJSON)], required: [String] = []) -> AnyJSON {
        var props: [String: AnyJSON] = [:]
        for (k, v) in pairs { props[k] = v }
        return .object([
            "type": .string("object"),
            "properties": .object(props),
            "required": .array(required.map { .string($0) }),
        ])
    }

    private static func string(_ description: String) -> AnyJSON {
        .object([
            "type": .string("string"),
            "description": .string(description),
        ])
    }

    private static func number(_ description: String) -> AnyJSON {
        .object([
            "type": .string("number"),
            "description": .string(description),
        ])
    }

    private static func int(_ description: String) -> AnyJSON {
        .object([
            "type": .string("integer"),
            "description": .string(description),
        ])
    }

    private static func bool(_ description: String) -> AnyJSON {
        .object([
            "type": .string("boolean"),
            "description": .string(description),
        ])
    }

    // MARK: - Tool definitions

    private static func queryTransactions() -> APITool {
        APITool(
            name: "query_transactions",
            description: "Search and filter the user's transactions by category, date range, type, amount, or note. Use to answer questions about spending, income, specific purchases, or merchants.",
            inputSchema: schemaDict(obj([
                ("category", string("Filter by category name (e.g. 'Alimentacion', 'Transporte')")),
                ("dateFrom", string("Start date in yyyy-MM-dd format")),
                ("dateTo", string("End date in yyyy-MM-dd format")),
                ("type", string("Filter by type: 'GASTO' for expenses or 'INGRESO' for income")),
                ("noteContains", string("Search in transaction notes (merchant name, description)")),
                ("amountMin", number("Minimum amount")),
                ("amountMax", number("Maximum amount")),
                ("limit", int("Max results to return (default 20)")),
            ]))
        )
    }

    private static func addTransaction() -> APITool {
        APITool(
            name: "add_transaction",
            description: "Create a new expense or income transaction. Always confirm details with the user before calling this tool.",
            inputSchema: schemaDict(obj([
                ("type", string("Transaction type: 'GASTO' for expense, 'INGRESO' for income")),
                ("amount", number("Amount as a positive number")),
                ("category", string("Category name (e.g. 'Alimentacion', 'Sueldo')")),
                ("subcategory", string("Optional subcategory")),
                ("note", string("Optional note or merchant name")),
                ("date", string("Date in yyyy-MM-dd format. Today if omitted.")),
            ], required: ["type", "amount", "category"]))
        )
    }

    private static func updateTransaction() -> APITool {
        APITool(
            name: "update_transaction",
            description: "Modify an existing transaction. First use query_transactions to find it. Only provided fields are changed.",
            inputSchema: schemaDict(obj([
                ("transactionId", string("UUID of the transaction to update")),
                ("amount", number("New amount")),
                ("category", string("New category")),
                ("subcategory", string("New subcategory")),
                ("note", string("New note")),
                ("date", string("New date in yyyy-MM-dd")),
                ("type", string("New type: 'GASTO' or 'INGRESO'")),
            ], required: ["transactionId"]))
        )
    }

    private static func deleteTransaction() -> APITool {
        APITool(
            name: "delete_transaction",
            description: "Delete a transaction by ID. Always confirm with the user first.",
            inputSchema: schemaDict(obj([
                ("transactionId", string("UUID of the transaction to delete")),
            ], required: ["transactionId"]))
        )
    }

    private static func getFinancialSummary() -> APITool {
        APITool(
            name: "get_financial_summary",
            description: "Get income, expenses, balance, savings rate, top categories, and previous-month comparison for a month.",
            inputSchema: schemaDict(obj([
                ("month", string("Month in yyyy-MM format (default: current month)")),
                ("includeComparison", bool("If true, include vs previous month")),
            ]))
        )
    }

    private static func getBudgetStatus() -> APITool {
        APITool(
            name: "get_budget_status",
            description: "Get envelope budget status: allocated vs spent per category, over-budget and near-limit alerts.",
            inputSchema: schemaDict(obj([
                ("month", string("Month in yyyy-MM format (default: current month)")),
            ]))
        )
    }

    private static func getNetWorth() -> APITool {
        APITool(
            name: "get_net_worth",
            description: "Calculate net worth: total assets minus liabilities, with breakdown by account.",
            inputSchema: schemaDict(obj([]))
        )
    }

    private static func getHealthScore() -> APITool {
        APITool(
            name: "get_financial_health_score",
            description: "Composite score 0-100 from savings rate, debt load, emergency fund, budget adherence, goal progress.",
            inputSchema: schemaDict(obj([]))
        )
    }

    private static func projectScenario() -> APITool {
        APITool(
            name: "project_scenario",
            description: "What-if projection: simulate impact of category cuts, raises, or fixed savings over months.",
            inputSchema: schemaDict(obj([
                ("scenario", string("Description of the scenario")),
                ("category", string("Category to modify (optional)")),
                ("percentChange", number("Percent change: e.g. -30 = 30% reduction")),
                ("fixedAmountChange", number("Fixed monthly amount change")),
                ("months", int("Months to project (default 3)")),
            ], required: ["scenario"]))
        )
    }

    private static func detectSpendingPatterns() -> APITool {
        APITool(
            name: "detect_spending_patterns",
            description: "Analyze monthly trends, day-of-week patterns, category growth/decline.",
            inputSchema: schemaDict(obj([
                ("monthsBack", int("Months of history (default 3, max 12)")),
                ("category", string("Focus on a specific category (optional)")),
            ]))
        )
    }

    private static func suggestSavings() -> APITool {
        APITool(
            name: "suggest_savings_opportunities",
            description: "Identify concrete savings opportunities based on spending patterns.",
            inputSchema: schemaDict(obj([
                ("targetSavings", number("Target monthly savings amount")),
            ]))
        )
    }

    private static func getGoals() -> APITool {
        APITool(
            name: "get_goals",
            description: "Get all goals with progress, ETA, and contribution suggestions.",
            inputSchema: schemaDict(obj([
                ("includeCompleted", bool("Include completed goals")),
            ]))
        )
    }

    private static func getAccounts() -> APITool {
        APITool(
            name: "get_accounts",
            description: "List financial accounts: checking, savings, cash, credit cards, investments, loans.",
            inputSchema: schemaDict(obj([
                ("includeInactive", bool("Include archived accounts")),
            ]))
        )
    }

    private static func getBills() -> APITool {
        APITool(
            name: "get_bills",
            description: "Upcoming bills with due dates, amounts, and urgency.",
            inputSchema: schemaDict(obj([
                ("daysAhead", int("Days ahead to look (default 30)")),
            ]))
        )
    }

    private static func analyzeInflation() -> APITool {
        APITool(
            name: "analyze_inflation_impact",
            description: "Inflation analysis: real purchasing power changes, price vs quantity changes per category.",
            inputSchema: schemaDict(obj([
                ("monthsBack", int("Months to compare (default 3)")),
                ("category", string("Focus on a category (optional)")),
            ]))
        )
    }

    // MARK: - JSON Schema converter

    private static func schemaDict(_ json: AnyJSON) -> [String: AnyJSON] {
        guard case .object(let dict) = json else { return [:] }
        return dict
    }
}
