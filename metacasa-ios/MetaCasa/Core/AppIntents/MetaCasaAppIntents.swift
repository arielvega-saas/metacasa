import AppIntents
import Foundation

/// App Intents de MetaCasa / MetaHome — exponen acciones a Siri, Spotlight,
/// Focus Modes, Shortcuts app y Home Screen widgets interactivos.
///
/// Requiere que el usuario esté autenticado. Si no lo está, los intents
/// retornan un dialog pidiendo que abra la app y se loguee — no manejamos
/// login via intent (Apple lo requiere en app).

// MARK: - AddExpenseIntent

struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Agregar gasto"
    static let description = IntentDescription(
        "Registra un gasto en tu hogar activo."
    )

    @Parameter(title: "Monto", description: "Cuánto gastaste")
    var amount: Double

    @Parameter(title: "Categoría", description: "En qué categoría (ej: Alimentación, Transporte)")
    var category: String

    @Parameter(title: "Nota", description: "Detalle opcional", default: "")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Cargar gasto de \(\.$amount) en \(\.$category)") {
            \.$note
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "El monto tiene que ser mayor a cero.")
        }

        // Intentar restaurar sesión. Si no hay, pedir login en app.
        guard let session = try? await AuthManager.shared.restoreSession() else {
            return .result(dialog: "Abrí la app y logueate primero.")
        }
        await TokenHolder.shared.set(session.accessToken)

        // Primer hogar del usuario. Si hay múltiples, por ahora toma el primero.
        // TODO post-launch: IntentParameter "hogar" con lista dinámica.
        let households = (try? await HouseholdService.shared.fetchMine()) ?? []
        guard let hid = households.first?.id else {
            return .result(dialog: "No tenés ningún hogar activo. Crealo en la app primero.")
        }

        let input = NewTransactionInput(
            householdId: hid,
            userId: session.userId,
            accountId: nil,
            type: .gasto,
            amount: Decimal(amount),
            currencyOriginal: nil,
            category: category,
            subcategory: nil,
            note: note.isEmpty ? nil : note,
            date: Date()
        )

        do {
            _ = try await TransactionService.shared.insert(input)
            let householdCurrency = households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
            let formatted = Money.format(Decimal(amount), currency: householdCurrency, style: .compact)
            return .result(dialog: "Listo, cargué un gasto de \(formatted) en \(category).")
        } catch {
            return .result(dialog: "No pude cargar el gasto: \(error.localizedDescription)")
        }
    }
}

// MARK: - CheckBalanceIntent

struct CheckBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Ver balance del mes"
    static let description = IntentDescription(
        "Consulta tu balance del mes actual."
    )

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let session = try? await AuthManager.shared.restoreSession() else {
            return .result(value: "", dialog: "Abrí la app y logueate primero.")
        }
        await TokenHolder.shared.set(session.accessToken)

        let households = (try? await HouseholdService.shared.fetchMine()) ?? []
        guard let household = households.first else {
            return .result(value: "", dialog: "No tenés ningún hogar activo.")
        }

        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59), to: start)
        else {
            return .result(value: "", dialog: "Error de fecha.")
        }

        do {
            let totals = try await TransactionService.shared.totals(
                householdId: household.id,
                from: start,
                to: end
            )
            let balance = totals.ingresos - totals.gastos
            let formatted = Money.format(balance, currency: household.defaultCurrency, style: .compact)
            let summary = "Tu balance del mes es \(formatted). Ingresos: \(Money.format(totals.ingresos, currency: household.defaultCurrency, style: .compact)). Gastos: \(Money.format(totals.gastos, currency: household.defaultCurrency, style: .compact))."
            return .result(value: summary, dialog: .init(stringLiteral: summary))
        } catch {
            return .result(value: "", dialog: "No pude consultar: \(error.localizedDescription)")
        }
    }
}

// MARK: - AddIncomeIntent

struct AddIncomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Registrar ingreso"
    static let description = IntentDescription(
        "Registra un ingreso (sueldo, venta, devolución) en tu hogar activo."
    )

    @Parameter(title: "Monto", description: "Cuánto ingresó")
    var amount: Double

    @Parameter(title: "Categoría", description: "Categoría (ej: Sueldo, Freelance)", default: "Sueldo")
    var category: String

    @Parameter(title: "Nota", description: "Detalle opcional", default: "")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar ingreso de \(\.$amount) en \(\.$category)") {
            \.$note
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "El monto tiene que ser mayor a cero.")
        }
        guard let session = try? await AuthManager.shared.restoreSession() else {
            return .result(dialog: "Abrí la app y logueate primero.")
        }
        await TokenHolder.shared.set(session.accessToken)

        let households = (try? await HouseholdService.shared.fetchMine()) ?? []
        guard let hid = households.first?.id else {
            return .result(dialog: "No tenés ningún hogar activo. Creálo en la app primero.")
        }

        let input = NewTransactionInput(
            householdId: hid,
            userId: session.userId,
            accountId: nil,
            type: .ingreso,
            amount: Decimal(amount),
            currencyOriginal: nil,
            category: category,
            subcategory: nil,
            note: note.isEmpty ? nil : note,
            date: Date()
        )

        do {
            _ = try await TransactionService.shared.insert(input)
            let currency = households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
            let formatted = Money.format(Decimal(amount), currency: currency, style: .compact)
            return .result(dialog: "Listo, registré un ingreso de \(formatted) en \(category).")
        } catch {
            return .result(dialog: "No pude registrar el ingreso: \(error.localizedDescription)")
        }
    }
}

// MARK: - CheckTopCategoriesIntent

struct CheckTopCategoriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Ver dónde gasto más"
    static let description = IntentDescription(
        "Muestra las 3 categorías donde más gastaste este mes."
    )

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let session = try? await AuthManager.shared.restoreSession() else {
            return .result(value: "", dialog: "Abrí la app y logueate primero.")
        }
        await TokenHolder.shared.set(session.accessToken)

        let households = (try? await HouseholdService.shared.fetchMine()) ?? []
        guard let household = households.first else {
            return .result(value: "", dialog: "No tenés ningún hogar activo.")
        }

        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start)
        else {
            return .result(value: "", dialog: "Error de fecha.")
        }

        do {
            let txs = try await TransactionService.shared.fetchForPeriod(
                householdId: household.id, from: start, to: end, limit: 5000
            )
            var sums: [String: Decimal] = [:]
            for t in txs where t.type == .gasto {
                sums[t.category, default: 0] += t.amount
            }
            let top3 = sums.map { ($0.key, $0.value) }
                .sorted { $0.1 > $1.1 }
                .prefix(3)
            guard !top3.isEmpty else {
                return .result(value: "", dialog: "No tenés gastos cargados este mes todavía.")
            }
            let curr = household.defaultCurrency
            let summary = top3.enumerated().map { idx, item in
                "\(idx + 1). \(item.0) con \(Money.format(item.1, currency: curr, style: .compact))"
            }.joined(separator: ". ")
            return .result(value: summary, dialog: .init(stringLiteral: "Top categorías este mes: \(summary)."))
        } catch {
            return .result(value: "", dialog: "No pude consultar: \(error.localizedDescription)")
        }
    }
}

// MARK: - CheckHealthScoreIntent

struct CheckHealthScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Ver mi salud financiera"
    static let description = IntentDescription(
        "Calcula tu Health Score 0-100 según savings rate y ratio gastos/ingresos."
    )

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let session = try? await AuthManager.shared.restoreSession() else {
            return .result(value: "", dialog: "Abrí la app y logueate primero.")
        }
        await TokenHolder.shared.set(session.accessToken)

        let households = (try? await HouseholdService.shared.fetchMine()) ?? []
        guard let household = households.first else {
            return .result(value: "", dialog: "No tenés ningún hogar activo.")
        }

        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start)
        else {
            return .result(value: "", dialog: "Error de fecha.")
        }

        do {
            let totals = try await TransactionService.shared.totals(
                householdId: household.id, from: start, to: end
            )
            let balance = totals.ingresos - totals.gastos
            let savingsRate: Double = totals.ingresos > 0
                ? ((balance / totals.ingresos) as NSDecimalNumber).doubleValue * 100
                : 0
            // Score simplificado: 50% savings rate, 50% expense ratio.
            let savingsScore = min(50, max(0, savingsRate * 2.5))
            let ratio: Double = totals.ingresos > 0
                ? ((totals.gastos / totals.ingresos) as NSDecimalNumber).doubleValue * 100
                : 100
            let ratioScore = max(0, 50 - max(0, ratio - 50))
            let score = Int(savingsScore + ratioScore)
            let label: String
            switch score {
            case 75...: label = "excelente"
            case 55..<75: label = "bueno"
            case 35..<55: label = "regular"
            default: label = "a mejorar"
            }
            let summary = "Tu salud financiera está \(label) con \(score) puntos sobre 100. Savings rate: \(Int(savingsRate)) por ciento."
            return .result(value: summary, dialog: .init(stringLiteral: summary))
        } catch {
            return .result(value: "", dialog: "No pude consultar: \(error.localizedDescription)")
        }
    }
}

// MARK: - CheckUpcomingBillsIntent

struct CheckUpcomingBillsIntent: AppIntent {
    static let title: LocalizedStringResource = "Ver vencimientos próximos"
    static let description = IntentDescription(
        "Lista las facturas y vencimientos pendientes de los próximos 7 días."
    )

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let session = try? await AuthManager.shared.restoreSession() else {
            return .result(value: "", dialog: "Abrí la app y logueate primero.")
        }
        await TokenHolder.shared.set(session.accessToken)

        let households = (try? await HouseholdService.shared.fetchMine()) ?? []
        guard let household = households.first else {
            return .result(value: "", dialog: "No tenés ningún hogar activo.")
        }

        do {
            let bills = try await BillService.shared.fetchUpcoming(
                householdId: household.id, daysAhead: 7
            )
            // `paidAt == nil` significa pendiente (todavía no pagada).
            let pending = bills.filter { $0.paidAt == nil }
            guard !pending.isEmpty else {
                return .result(value: "", dialog: "No tenés vencimientos pendientes en los próximos 7 días.")
            }
            let df = DateFormatter()
            df.dateStyle = .short
            df.locale = Locale(identifier: "es_AR")
            let curr = household.defaultCurrency
            let preview = pending.prefix(3).map { b in
                let amt = Money.format(b.amount, currency: curr, style: .compact)
                return "\(b.title) por \(amt) el \(df.string(from: b.dueDate))"
            }.joined(separator: ". ")
            let suffix = pending.count > 3 ? " Y otros \(pending.count - 3) más." : ""
            let summary = "Tenés \(pending.count) vencimientos próximos. \(preview).\(suffix)"
            return .result(value: summary, dialog: .init(stringLiteral: summary))
        } catch {
            return .result(value: "", dialog: "No pude consultar: \(error.localizedDescription)")
        }
    }
}

// MARK: - OpenAssistantIntent

struct OpenAssistantIntent: AppIntent {
    static let title: LocalizedStringResource = "Hablar con el asistente"
    static let description = IntentDescription(
        "Abre el Asistente IA financiero de MetaCasa."
    )

    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        // Abrir la app es suficiente para iniciar — el user puede tocar el
        // botón flotante del asistente desde cualquier tab. En un sprint
        // futuro podríamos rutear directo al chat via deep link.
        return .result()
    }
}

// MARK: - Shortcuts Provider

struct MetaCasaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "Cuánto balance tengo en \(.applicationName)",
                "Ver mi balance en \(.applicationName)",
                "Check my balance in \(.applicationName)",
                "What's my balance in \(.applicationName)"
            ],
            shortTitle: "Ver balance",
            systemImageName: "dollarsign.circle.fill"
        )
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Cargar gasto en \(.applicationName)",
                "Agregar gasto a \(.applicationName)",
                "Add expense to \(.applicationName)",
                "Log expense in \(.applicationName)"
            ],
            shortTitle: "Cargar gasto",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: [
                "Registrar ingreso en \(.applicationName)",
                "Cargar sueldo en \(.applicationName)",
                "Add income to \(.applicationName)",
                "Log income in \(.applicationName)"
            ],
            shortTitle: "Registrar ingreso",
            systemImageName: "arrow.down.circle.fill"
        )
        AppShortcut(
            intent: CheckTopCategoriesIntent(),
            phrases: [
                "Dónde gasto más en \(.applicationName)",
                "Top categorías en \(.applicationName)",
                "Where do I spend the most in \(.applicationName)",
                "Top categories in \(.applicationName)"
            ],
            shortTitle: "Dónde gasto más",
            systemImageName: "chart.pie.fill"
        )
        AppShortcut(
            intent: CheckHealthScoreIntent(),
            phrases: [
                "Mi salud financiera en \(.applicationName)",
                "Health score en \(.applicationName)",
                "My financial health in \(.applicationName)",
                "Financial health score in \(.applicationName)"
            ],
            shortTitle: "Salud financiera",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: CheckUpcomingBillsIntent(),
            phrases: [
                "Próximos vencimientos en \(.applicationName)",
                "Qué tengo que pagar en \(.applicationName)",
                "Upcoming bills in \(.applicationName)",
                "What do I owe in \(.applicationName)"
            ],
            shortTitle: "Próximos vencimientos",
            systemImageName: "calendar.badge.exclamationmark"
        )
        AppShortcut(
            intent: OpenAssistantIntent(),
            phrases: [
                "Hablar con el asistente de \(.applicationName)",
                "Abrí el asistente de \(.applicationName)",
                "Talk to the \(.applicationName) assistant",
                "Open \(.applicationName) assistant"
            ],
            shortTitle: "Hablar con el asistente",
            systemImageName: "sparkles"
        )
    }
}
