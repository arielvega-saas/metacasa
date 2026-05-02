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
    }
}
