import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - 1. Query Transactions

@available(iOS 26.0, *)
struct QueryTransactionsTool: Tool {
    typealias Output = String

    let name = "query_transactions"
    let description = """
    Search and filter the user's transactions. Use this to answer questions about spending, \
    income, specific purchases, merchants, date ranges, amounts, or categories. \
    Returns a list of matching transactions with totals.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Filter by category name (e.g. 'Alimentacion', 'Transporte')")
        var category: String?
        @Guide(description: "Start date in yyyy-MM-dd format")
        var dateFrom: String?
        @Guide(description: "End date in yyyy-MM-dd format")
        var dateTo: String?
        @Guide(description: "Filter by type: 'GASTO' for expenses or 'INGRESO' for income")
        var type: String?
        @Guide(description: "Search in transaction notes (merchant name, description)")
        var noteContains: String?
        @Guide(description: "Minimum amount")
        var amountMin: Double?
        @Guide(description: "Maximum amount")
        var amountMax: Double?
        @Guide(description: "Maximum number of results to return (default 20)")
        var limit: Int?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.queryTransactions(arguments)
    }
}

// MARK: - 2. Add Transaction

@available(iOS 26.0, *)
struct AddTransactionTool: Tool {
    typealias Output = String

    let name = "add_transaction"
    let description = """
    Create a new transaction (expense or income). Use when the user says things like \
    "I spent $50 on groceries" or "Add my salary of $3000". Always confirm the details \
    with the user before calling this tool.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Transaction type: 'GASTO' for expense, 'INGRESO' for income")
        var type: String
        @Guide(description: "Amount as a positive number")
        var amount: Double
        @Guide(description: "Category name (e.g. 'Alimentacion', 'Transporte', 'Sueldo')")
        var category: String
        @Guide(description: "Optional subcategory")
        var subcategory: String?
        @Guide(description: "Optional note or merchant name")
        var note: String?
        @Guide(description: "Date in yyyy-MM-dd format. Use today if not specified")
        var date: String?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.addTransaction(arguments)
    }
}

// MARK: - 3. Update Transaction

@available(iOS 26.0, *)
struct UpdateTransactionTool: Tool {
    typealias Output = String

    let name = "update_transaction"
    let description = """
    Modify an existing transaction. First use query_transactions to find the transaction, \
    then update it. Only provided fields will be changed.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The UUID of the transaction to update")
        var transactionId: String
        @Guide(description: "New amount (positive number)")
        var amount: Double?
        @Guide(description: "New category")
        var category: String?
        @Guide(description: "New subcategory")
        var subcategory: String?
        @Guide(description: "New note")
        var note: String?
        @Guide(description: "New date in yyyy-MM-dd format")
        var date: String?
        @Guide(description: "New type: 'GASTO' or 'INGRESO'")
        var type: String?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.updateTransaction(arguments)
    }
}

// MARK: - 4. Delete Transaction

@available(iOS 26.0, *)
struct DeleteTransactionTool: Tool {
    typealias Output = String

    let name = "delete_transaction"
    let description = """
    Delete a transaction by its ID. Always confirm with the user before deleting. \
    Use query_transactions first to find the exact transaction.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The UUID of the transaction to delete")
        var transactionId: String
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.deleteTransaction(arguments)
    }
}

// MARK: - 5. Financial Summary

@available(iOS 26.0, *)
struct GetFinancialSummaryTool: Tool {
    typealias Output = String

    let name = "get_financial_summary"
    let description = """
    Get a comprehensive financial summary for a specific month or date range. \
    Includes income, expenses, balance, savings rate, top categories, and comparison \
    with previous period. Use this for questions like "how am I doing this month?" \
    or "summary of March".
    """

    @Generable
    struct Arguments {
        @Guide(description: "Month in yyyy-MM format (default: current month)")
        var month: String?
        @Guide(description: "If true, include comparison with previous month")
        var includeComparison: Bool?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.getFinancialSummary(arguments)
    }
}

// MARK: - 6. Budget Status

@available(iOS 26.0, *)
struct GetBudgetStatusTool: Tool {
    typealias Output = String

    let name = "get_budget_status"
    let description = """
    Get the current envelope budget status: allocated vs spent per category, \
    which envelopes are over budget or near limit, and how much is left to assign. \
    Use for budget-related questions.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Month in yyyy-MM format (default: current month)")
        var month: String?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.getBudgetStatus(arguments)
    }
}

// MARK: - 7. Net Worth

@available(iOS 26.0, *)
struct GetNetWorthTool: Tool {
    typealias Output = String

    let name = "get_net_worth"
    let description = """
    Calculate the user's net worth: total assets (checking, savings, cash, investments) \
    minus total liabilities (credit cards, loans, debts). Includes breakdown by account.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Placeholder parameter, not used")
        var unused: String?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.getNetWorth()
    }
}

// MARK: - 8. Financial Health Score

@available(iOS 26.0, *)
struct GetHealthScoreTool: Tool {
    typealias Output = String

    let name = "get_financial_health_score"
    let description = """
    Calculate a financial health score (0-100) based on: savings rate, debt load ratio, \
    emergency fund coverage, budget adherence, and goal progress. Provides a breakdown \
    of each component with actionable tips.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Placeholder parameter, not used")
        var unused: String?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.getHealthScore()
    }
}

// MARK: - 9. Project Scenario (What-if)

@available(iOS 26.0, *)
struct ProjectScenarioTool: Tool {
    typealias Output = String

    let name = "project_scenario"
    let description = """
    Run a what-if financial projection. Simulate changes like "what if I reduce eating out \
    by 30%?" or "what if I get a 20% raise?" or "what if I save $500/month for 12 months?". \
    Shows projected impact on balance, savings, and goals.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Description of the scenario to simulate")
        var scenario: String
        @Guide(description: "Category to modify (if applicable)")
        var category: String?
        @Guide(description: "Percentage change: positive = increase, negative = decrease (e.g. -30 for 30% reduction)")
        var percentChange: Double?
        @Guide(description: "Fixed monthly amount change (positive = more income/savings, negative = more expense)")
        var fixedAmountChange: Double?
        @Guide(description: "Number of months to project (default 3)")
        var months: Int?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.projectScenario(arguments)
    }
}

// MARK: - 10. Detect Spending Patterns

@available(iOS 26.0, *)
struct DetectSpendingPatternsTool: Tool {
    typealias Output = String

    let name = "detect_spending_patterns"
    let description = """
    Analyze spending patterns over time: weekly trends, day-of-week habits, \
    category growth/decline, recurring charges, seasonal patterns. \
    Use for deep analysis questions.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Number of months of history to analyze (default 3, max 12)")
        var monthsBack: Int?
        @Guide(description: "Focus on a specific category (optional)")
        var category: String?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.detectSpendingPatterns(arguments)
    }
}

// MARK: - 11. Suggest Savings Opportunities

@available(iOS 26.0, *)
struct SuggestSavingsTool: Tool {
    typealias Output = String

    let name = "suggest_savings_opportunities"
    let description = """
    Identify concrete savings opportunities based on the user's spending data: \
    categories with room to cut, potential duplicate subscriptions, impulse spending \
    patterns, and comparison with recommended budgets.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Target monthly savings amount the user wants to achieve")
        var targetSavings: Double?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.suggestSavings(arguments)
    }
}

// MARK: - 12. Get Goals

@available(iOS 26.0, *)
struct GetGoalsTool: Tool {
    typealias Output = String

    let name = "get_goals"
    let description = """
    Get all savings goals with detailed progress: current amount, target, percentage, \
    estimated completion date based on contribution pace, and suggestions to accelerate.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Include completed goals")
        var includeCompleted: Bool?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.getGoals(arguments)
    }
}

// MARK: - 13. Get Accounts

@available(iOS 26.0, *)
struct GetAccountsTool: Tool {
    typealias Output = String

    let name = "get_accounts"
    let description = """
    List all financial accounts with their types, balances, and status. \
    Includes checking, savings, cash, credit cards, investments, and loans.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Include inactive/archived accounts")
        var includeInactive: Bool?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.getAccounts(arguments)
    }
}

// MARK: - 14. Get Bills

@available(iOS 26.0, *)
struct GetBillsTool: Tool {
    typealias Output = String

    let name = "get_bills"
    let description = """
    Get upcoming bills and payment obligations. Shows due dates, amounts, \
    status (pending/paid/overdue), and urgency level.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Number of days ahead to look (default 30)")
        var daysAhead: Int?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.getBills(arguments)
    }
}

// MARK: - 15. Analyze Inflation Impact

@available(iOS 26.0, *)
struct AnalyzeInflationTool: Tool {
    typealias Output = String

    let name = "analyze_inflation_impact"
    let description = """
    Analyze how inflation (especially relevant for Argentina and Latin America) affects \
    the user's finances: real purchasing power changes, category-level price increases, \
    whether spending growth is due to price or quantity changes. \
    Use for questions about inflation, purchasing power, or "why am I spending more?".
    """

    @Generable
    struct Arguments {
        @Guide(description: "Number of months to compare (default 3)")
        var monthsBack: Int?
        @Guide(description: "Focus on a specific category")
        var category: String?
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.analyzeInflation(arguments)
    }
}

// MARK: - 16. Mark Bill Paid

@available(iOS 26.0, *)
struct MarkBillPaidTool: Tool {
    typealias Output = String

    let name = "mark_bill_paid"
    let description = """
    Mark a bill/upcoming payment as paid. First use get_bills to find the \
    correct bill by name or date, then pass its UUID. Always confirm with \
    the user before executing this tool.
    """

    @Generable
    struct Arguments {
        @Guide(description: "UUID of the bill to mark as paid")
        var billId: String
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.markBillPaid(arguments)
    }
}

// MARK: - 17. Compare Periods

@available(iOS 26.0, *)
struct ComparePeriodsTool: Tool {
    typealias Output = String

    let name = "compare_periods"
    let description = """
    Compare two time periods side by side: income, expenses, balance, \
    savings rate, top categories, and per-category deltas. Useful for \
    "compare March vs February" or "this month vs same month last year".
    """

    @Generable
    struct Arguments {
        @Guide(description: "First period in yyyy-MM format (e.g. 2026-04)")
        var periodA: String
        @Guide(description: "Second period in yyyy-MM format (e.g. 2026-03 or 2025-04 for YoY)")
        var periodB: String
    }

    let handler: AIToolHandler

    func call(arguments: Arguments) async throws -> String {
        try await handler.comparePeriods(arguments)
    }
}

#endif
