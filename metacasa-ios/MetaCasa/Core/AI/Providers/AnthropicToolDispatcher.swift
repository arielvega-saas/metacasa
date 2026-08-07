import Foundation

/// Dispatcher que mapea tool calls del cloud LLM a `AIToolHandler`.
///
/// Recibe el `name` de la tool + el `input` (dict JSON) y ejecuta la tool
/// correspondiente. **Corre en cualquier iOS soportado por la app (17+)**: los
/// argumentos son los structs planos de `AIToolArgs.swift`, no los `@Generable`
/// de FoundationModels.
///
/// Antes esto estaba gateado a iOS 26 y devolvía "Tool execution requires
/// iOS 26+" — no porque hiciera falta Apple Intelligence para ejecutar nada,
/// sino porque las firmas del handler nombraban `XxxTool.Arguments`. En un
/// iPhone anterior el asistente no podía cargar un solo movimiento aunque el
/// modelo (Claude, en la nube) hubiera decidido perfectamente qué hacer.
@MainActor
enum AnthropicToolDispatcher {

    static func dispatch(
        name: String,
        input: [String: AnyJSON],
        handler: AIToolHandler
    ) async throws -> String {
        switch name {
        case "query_transactions":
            return try await handler.queryTransactions(queryTransactionsArgs(from: input))

        case "add_transaction":
            guard let args = addTransactionArgs(from: input) else {
                return "Error: missing required field (type, amount, or category)"
            }
            return try await handler.addTransaction(args)

        case "update_transaction":
            guard let id = input["transactionId"]?.stringValue else {
                return "Error: transactionId required"
            }
            let args = UpdateTransactionArgs(
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
                DeleteTransactionArgs(transactionId: id)
            )

        case "get_financial_summary":
            return try await handler.getFinancialSummary(
                GetFinancialSummaryArgs(
                    month: input["month"]?.stringValue,
                    includeComparison: input["includeComparison"]?.boolValue
                )
            )

        case "get_budget_status":
            return try await handler.getBudgetStatus(
                GetBudgetStatusArgs(month: input["month"]?.stringValue)
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
                ProjectScenarioArgs(
                    scenario: scenario,
                    category: input["category"]?.stringValue,
                    percentChange: input["percentChange"]?.doubleValue,
                    fixedAmountChange: input["fixedAmountChange"]?.doubleValue,
                    months: input["months"]?.intValue
                )
            )

        case "detect_spending_patterns":
            return try await handler.detectSpendingPatterns(
                DetectSpendingPatternsArgs(
                    monthsBack: input["monthsBack"]?.intValue,
                    category: input["category"]?.stringValue
                )
            )

        case "suggest_savings_opportunities":
            return try await handler.suggestSavings(
                SuggestSavingsArgs(
                    targetSavings: input["targetSavings"]?.doubleValue
                )
            )

        case "get_goals":
            return try await handler.getGoals(
                GetGoalsArgs(
                    includeCompleted: input["includeCompleted"]?.boolValue
                )
            )

        case "get_accounts":
            return try await handler.getAccounts(
                GetAccountsArgs(
                    includeInactive: input["includeInactive"]?.boolValue
                )
            )

        case "get_bills":
            return try await handler.getBills(
                GetBillsArgs(
                    daysAhead: input["daysAhead"]?.intValue
                )
            )

        case "analyze_inflation_impact":
            return try await handler.analyzeInflation(
                AnalyzeInflationArgs(
                    monthsBack: input["monthsBack"]?.intValue,
                    category: input["category"]?.stringValue
                )
            )

        case "mark_bill_paid":
            guard let id = input["billId"]?.stringValue else {
                return "Error: billId required"
            }
            return try await handler.markBillPaid(
                MarkBillPaidArgs(billId: id)
            )

        case "compare_periods":
            guard let a = input["periodA"]?.stringValue,
                  let b = input["periodB"]?.stringValue else {
                return "Error: periodA and periodB required (yyyy-MM)"
            }
            return try await handler.comparePeriods(
                ComparePeriodsArgs(periodA: a, periodB: b)
            )

        case "set_budget_envelope":
            guard let category = input["category"]?.stringValue,
                  let amount = input["amount"]?.doubleValue else {
                return "Error: category and amount required"
            }
            return try await handler.setBudgetEnvelope(
                SetBudgetEnvelopeArgs(
                    category: category,
                    amount: amount,
                    subcategory: input["subcategory"]?.stringValue,
                    month: input["month"]?.stringValue
                )
            )

        case "transfer_between_accounts":
            guard let from = input["fromAccountId"]?.stringValue,
                  let to = input["toAccountId"]?.stringValue,
                  let amount = input["amount"]?.doubleValue else {
                return "Error: fromAccountId, toAccountId, amount required"
            }
            return try await handler.transferBetweenAccounts(
                TransferBetweenAccountsArgs(
                    fromAccountId: from,
                    toAccountId: to,
                    amount: amount,
                    note: input["note"]?.stringValue
                )
            )

        case "categorize_transaction":
            guard let text = input["text"]?.stringValue else {
                return "Error: text required"
            }
            return try await handler.categorizeTransaction(
                CategorizeTransactionArgs(text: text)
            )

        case "validate_cfdi":
            guard let qrText = input["qrText"]?.stringValue else {
                return "Error: qrText required (the QR text or verification URL)"
            }
            return try await handler.validateCFDI(
                ValidateCFDIArgs(qrText: qrText)
            )

        case "validate_arca":
            guard let cae = input["cae"]?.stringValue else {
                return "Error: cae required (the 14-digit CAE)"
            }
            return try await handler.validateARCA(
                ValidateARCAArgs(
                    cae: cae,
                    comprobante: input["comprobante"]?.stringValue,
                    total: input["total"]?.doubleValue
                )
            )

        default:
            return "Error: unknown tool '\(name)'"
        }
    }

    // MARK: - Parseo (funciones puras, testeables)

    /// Las dos tools que más se ejercitan —consultar y cargar— tienen su parseo
    /// separado del `switch` a propósito: es lo único del dispatcher que se
    /// puede verificar sin red ni sesión, y es exactamente lo que el gate de
    /// iOS 26 rompía. El resto arma sus args inline porque el `switch` sigue
    /// siendo la forma más legible de leer las 22 de un vistazo.

    static func queryTransactionsArgs(from input: [String: AnyJSON]) -> QueryTransactionsArgs {
        QueryTransactionsArgs(
            category: input["category"]?.stringValue,
            dateFrom: input["dateFrom"]?.stringValue,
            dateTo: input["dateTo"]?.stringValue,
            type: input["type"]?.stringValue,
            noteContains: input["noteContains"]?.stringValue,
            amountMin: input["amountMin"]?.doubleValue,
            amountMax: input["amountMax"]?.doubleValue,
            limit: input["limit"]?.intValue
        )
    }

    /// `nil` cuando falta alguno de los tres campos obligatorios.
    static func addTransactionArgs(from input: [String: AnyJSON]) -> AddTransactionArgs? {
        guard let type = input["type"]?.stringValue,
              let amount = input["amount"]?.doubleValue,
              let category = input["category"]?.stringValue else {
            return nil
        }
        return AddTransactionArgs(
            type: type,
            amount: amount,
            category: category,
            subcategory: input["subcategory"]?.stringValue,
            note: input["note"]?.stringValue,
            date: input["date"]?.stringValue
        )
    }
}
