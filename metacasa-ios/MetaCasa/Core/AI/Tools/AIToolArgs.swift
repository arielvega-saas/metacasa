import Foundation

// Argumentos de las 22 tools del asistente, en versión PLANA.
//
// Por qué existe este archivo: los `Arguments` que declara cada `Tool` en
// `AIToolDefinitions.swift` viven dentro de un `struct … : Tool` marcado
// `@available(iOS 26.0, *)` y con la macro `@Generable` de FoundationModels.
// Cuando `AIToolHandler` tomaba ESOS tipos en sus firmas, heredaba el gate de
// iOS 26 sin usar una sola API de iOS 26 en sus cuerpos: el acoplamiento era
// puramente nominal. Consecuencia real: en cualquier iPhone anterior a iOS 26
// el camino cloud (Anthropic) no podía ejecutar NINGUNA tool, y el asistente
// prometía "contame lo que gastaste y lo cargo yo" sin poder cumplirlo.
//
// Estos structs son el contrato de argumentos del handler. Sin `@Generable`,
// sin `@Guide`, sin `@available` y fuera de cualquier `#if canImport`:
// compilan desde iOS 17. Los `@Generable` siguen existiendo (FoundationModels
// los exige para el schema on-device) y se convierten a estos con `.plain`
// justo antes de llamar al handler; el dispatcher cloud los construye directo
// desde el JSON.
//
// Los nombres y la opcionalidad de los campos son EXACTAMENTE los de los
// `Arguments` correspondientes: si divergen, la conversión deja de compilar,
// que es el aviso que queremos.

// MARK: - 1. Query Transactions

struct QueryTransactionsArgs: Sendable {
    var category: String?
    var dateFrom: String?
    var dateTo: String?
    var type: String?
    var noteContains: String?
    var amountMin: Double?
    var amountMax: Double?
    var limit: Int?
}

// MARK: - 2. Add Transaction

struct AddTransactionArgs: Sendable {
    var type: String
    var amount: Double
    var category: String
    var subcategory: String?
    var note: String?
    var date: String?
}

// MARK: - 3. Update Transaction

struct UpdateTransactionArgs: Sendable {
    var transactionId: String
    var amount: Double?
    var category: String?
    var subcategory: String?
    var note: String?
    var date: String?
    var type: String?
}

// MARK: - 4. Delete Transaction

struct DeleteTransactionArgs: Sendable {
    var transactionId: String
}

// MARK: - 5. Financial Summary

struct GetFinancialSummaryArgs: Sendable {
    var month: String?
    var includeComparison: Bool?
}

// MARK: - 6. Budget Status

struct GetBudgetStatusArgs: Sendable {
    var month: String?
}

// MARK: - 7. Net Worth

/// `unused` existe sólo porque el schema de la tool necesita al menos un campo;
/// el handler (`getNetWorth()`) no recibe argumentos.
struct GetNetWorthArgs: Sendable {
    var unused: String?
}

// MARK: - 8. Financial Health Score

/// Ídem `GetNetWorthArgs`: placeholder de schema, el handler no lo usa.
struct GetHealthScoreArgs: Sendable {
    var unused: String?
}

// MARK: - 9. Project Scenario

struct ProjectScenarioArgs: Sendable {
    var scenario: String
    var category: String?
    var percentChange: Double?
    var fixedAmountChange: Double?
    var months: Int?
}

// MARK: - 10. Detect Spending Patterns

struct DetectSpendingPatternsArgs: Sendable {
    var monthsBack: Int?
    var category: String?
}

// MARK: - 11. Suggest Savings Opportunities

struct SuggestSavingsArgs: Sendable {
    var targetSavings: Double?
}

// MARK: - 12. Get Goals

struct GetGoalsArgs: Sendable {
    var includeCompleted: Bool?
}

// MARK: - 13. Get Accounts

struct GetAccountsArgs: Sendable {
    var includeInactive: Bool?
}

// MARK: - 14. Get Bills

struct GetBillsArgs: Sendable {
    var daysAhead: Int?
}

// MARK: - 15. Analyze Inflation Impact

struct AnalyzeInflationArgs: Sendable {
    var monthsBack: Int?
    var category: String?
}

// MARK: - 16. Mark Bill Paid

struct MarkBillPaidArgs: Sendable {
    var billId: String
}

// MARK: - 17. Compare Periods

struct ComparePeriodsArgs: Sendable {
    var periodA: String
    var periodB: String
}

// MARK: - 18. Set Budget Envelope

struct SetBudgetEnvelopeArgs: Sendable {
    var category: String
    var amount: Double
    var subcategory: String?
    var month: String?
}

// MARK: - 19. Transfer Between Accounts

struct TransferBetweenAccountsArgs: Sendable {
    var fromAccountId: String
    var toAccountId: String
    var amount: Double
    var note: String?
}

// MARK: - 20. Categorize Transaction

struct CategorizeTransactionArgs: Sendable {
    var text: String
}

// MARK: - 21. Validate CFDI (Mexico)

struct ValidateCFDIArgs: Sendable {
    var qrText: String
}

// MARK: - 22. Validate ARCA (Argentina)

struct ValidateARCAArgs: Sendable {
    var cae: String
    var comprobante: String?
    var total: Double?
}
