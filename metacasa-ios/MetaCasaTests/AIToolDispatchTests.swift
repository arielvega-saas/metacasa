import XCTest
@testable import Home_Finance

/// El asistente puede ejecutar tools en iOS 17, no sólo en iOS 26.
///
/// El bug que cubren estos tests no era de lógica: `AIToolHandler` nunca usó una
/// API de FoundationModels, pero sus firmas nombraban `XxxTool.Arguments`
/// —structs `@Generable` anidados en tools `@available(iOS 26.0, *)`— y con eso
/// heredaban el gate. `AnthropicToolDispatcher` lo hacía visible: en cualquier
/// iPhone anterior a iOS 26 devolvía "Tool execution requires iOS 26+" y el
/// asistente no podía cargar un solo movimiento, aunque Claude (en la nube) ya
/// hubiera decidido perfectamente qué hacer.
///
/// La garantía es en parte de compilación: este target tiene deployment target
/// 17.0, así que si los args volvieran a quedar detrás de un `@available` este
/// archivo directamente no compila.
@MainActor
final class AIToolDispatchTests: XCTestCase {

    private func handler() -> AIToolHandler {
        AIToolHandler(householdId: UUID(), userId: UUID(), currency: "ARS")
    }

    // MARK: - add_transaction

    func testAddTransactionArmaLosArgsDesdeElJSON() {
        let args = AnthropicToolDispatcher.addTransactionArgs(from: [
            "type": .string("GASTO"),
            "amount": .double(12500.5),
            "category": .string("Alimentacion"),
            "subcategory": .string("Super"),
            "note": .string("Coto"),
            "date": .string("2026-08-04"),
        ])

        XCTAssertEqual(args?.type, "GASTO")
        XCTAssertEqual(args?.amount, 12500.5)
        XCTAssertEqual(args?.category, "Alimentacion")
        XCTAssertEqual(args?.subcategory, "Super")
        XCTAssertEqual(args?.note, "Coto")
        XCTAssertEqual(args?.date, "2026-08-04")
    }

    /// Sólo los tres obligatorios: el resto tiene que quedar `nil`, no en
    /// string vacío ni en 0 — el handler distingue "no lo dijo" de "lo dijo
    /// vacío" (ej. `date == nil` ⇒ hoy).
    func testAddTransactionDejaEnNilLosOpcionalesAusentes() {
        let args = AnthropicToolDispatcher.addTransactionArgs(from: [
            "type": .string("INGRESO"),
            "amount": .int(3000),          // el modelo puede mandar entero
            "category": .string("Sueldo"),
        ])

        XCTAssertEqual(args?.type, "INGRESO")
        XCTAssertEqual(args?.amount, 3000)  // `.int` se lee como Double
        XCTAssertEqual(args?.category, "Sueldo")
        XCTAssertNil(args?.subcategory)
        XCTAssertNil(args?.note)
        XCTAssertNil(args?.date)
    }

    func testAddTransactionSinCampoObligatorioNoArmaArgs() {
        XCTAssertNil(AnthropicToolDispatcher.addTransactionArgs(from: [
            "amount": .double(100),
            "category": .string("Transporte"),
        ]), "falta type")

        XCTAssertNil(AnthropicToolDispatcher.addTransactionArgs(from: [
            "type": .string("GASTO"),
            "category": .string("Transporte"),
        ]), "falta amount")

        XCTAssertNil(AnthropicToolDispatcher.addTransactionArgs(from: [
            "type": .string("GASTO"),
            "amount": .double(100),
        ]), "falta category")
    }

    // MARK: - query_transactions

    func testQueryTransactionsArmaLosArgsDesdeElJSON() {
        let args = AnthropicToolDispatcher.queryTransactionsArgs(from: [
            "category": .string("Transporte"),
            "dateFrom": .string("2026-07-01"),
            "dateTo": .string("2026-07-31"),
            "type": .string("GASTO"),
            "noteContains": .string("uber"),
            "amountMin": .double(500),
            "amountMax": .int(20000),
            "limit": .int(10),
        ])

        XCTAssertEqual(args.category, "Transporte")
        XCTAssertEqual(args.dateFrom, "2026-07-01")
        XCTAssertEqual(args.dateTo, "2026-07-31")
        XCTAssertEqual(args.type, "GASTO")
        XCTAssertEqual(args.noteContains, "uber")
        XCTAssertEqual(args.amountMin, 500)
        XCTAssertEqual(args.amountMax, 20000)
        XCTAssertEqual(args.limit, 10)
    }

    /// `query_transactions` no tiene campos obligatorios: un input vacío es
    /// válido y significa "los defaults del handler".
    func testQueryTransactionsConInputVacioDejaTodoEnNil() {
        let args = AnthropicToolDispatcher.queryTransactionsArgs(from: [:])

        XCTAssertNil(args.category)
        XCTAssertNil(args.dateFrom)
        XCTAssertNil(args.dateTo)
        XCTAssertNil(args.type)
        XCTAssertNil(args.noteContains)
        XCTAssertNil(args.amountMin)
        XCTAssertNil(args.amountMax)
        XCTAssertNil(args.limit)
    }

    // MARK: - dispatch

    /// Llega al `switch` sin pasar por ningún chequeo de versión: la respuesta
    /// es la validación de la propia tool, no "requires iOS 26+".
    func testDispatchNoRespondeConElErrorDeVersion() async throws {
        let sinCampos = try await AnthropicToolDispatcher.dispatch(
            name: "add_transaction",
            input: [:],
            handler: handler()
        )
        XCTAssertEqual(sinCampos, "Error: missing required field (type, amount, or category)")

        let desconocida = try await AnthropicToolDispatcher.dispatch(
            name: "no_existe",
            input: [:],
            handler: handler()
        )
        XCTAssertEqual(desconocida, "Error: unknown tool 'no_existe'")

        for respuesta in [sinCampos, desconocida] {
            XCTAssertFalse(respuesta.contains("iOS 26"), "el gate de versión volvió: \(respuesta)")
        }
    }

    // MARK: - Contrato completo

    /// Las 22 tools tienen sus argumentos construibles en iOS 17. Si alguno
    /// volviera a depender de `@Generable`/`@available`, esto no compila.
    func testLas22ToolsTienenArgsConstruiblesSinIOS26() {
        _ = QueryTransactionsArgs()
        _ = AddTransactionArgs(type: "GASTO", amount: 1, category: "Otro")
        _ = UpdateTransactionArgs(transactionId: "id")
        _ = DeleteTransactionArgs(transactionId: "id")
        _ = GetFinancialSummaryArgs()
        _ = GetBudgetStatusArgs()
        _ = GetNetWorthArgs()
        _ = GetHealthScoreArgs()
        _ = ProjectScenarioArgs(scenario: "que pasa si")
        _ = DetectSpendingPatternsArgs()
        _ = SuggestSavingsArgs()
        _ = GetGoalsArgs()
        _ = GetAccountsArgs()
        _ = GetBillsArgs()
        _ = AnalyzeInflationArgs()
        _ = MarkBillPaidArgs(billId: "id")
        _ = ComparePeriodsArgs(periodA: "2026-07", periodB: "2026-06")
        _ = SetBudgetEnvelopeArgs(category: "Alimentacion", amount: 1)
        _ = TransferBetweenAccountsArgs(fromAccountId: "a", toAccountId: "b", amount: 1)
        _ = CategorizeTransactionArgs(text: "coto")
        _ = ValidateCFDIArgs(qrText: "qr")
        _ = ValidateARCAArgs(cae: "12345678901234")
    }
}
