import SwiftUI

struct AddAccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: AccountType = .checking
    @State private var currency = "USD"
    @State private var initialBalance = ""
    @State private var institution = ""

    // Credit card fields
    @State private var creditLimit = ""
    @State private var statementDay = 1
    @State private var dueDay = 15
    @State private var interestRate = ""
    @State private var minPaymentPct = "5"
    @State private var network: CardNetwork = .visa

    @State private var isLoading = false
    @State private var errorMessage: String?

    let onSaved: () async -> Void

    private var isCreditCard: Bool { type == .creditCard }

    var body: some View {
        NavigationStack {
            Form {
                Section("Básico") {
                    TextField("Nombre (ej: Santander Platinum)", text: $name)
                    Picker("Tipo", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) { t in
                            Label(t.label, systemImage: t.systemIcon).tag(t)
                        }
                    }
                    HStack {
                        Text("Moneda")
                        Spacer()
                        CurrencyPickerButton(selectedCode: $currency, label: "")
                    }
                }

                Section("Opcional") {
                    TextField("Institución (banco, billetera)", text: $institution)
                    if !isCreditCard {
                        TextField("Saldo inicial", text: $initialBalance)
                            .keyboardType(.decimalPad)
                    }
                }

                if isCreditCard {
                    Section("Tarjeta de crédito") {
                        TextField("Límite de crédito", text: $creditLimit).keyboardType(.decimalPad)
                        Stepper("Día de cierre: \(statementDay)", value: $statementDay, in: 1...31)
                        Stepper("Día de vencimiento: \(dueDay)", value: $dueDay, in: 1...31)
                        TextField("Interés mensual % (ej: 5.5)", text: $interestRate).keyboardType(.decimalPad)
                        TextField("Mínimo a pagar % (ej: 5)", text: $minPaymentPct).keyboardType(.decimalPad)
                        Picker("Red", selection: $network) {
                            ForEach([CardNetwork.visa, .mastercard, .amex, .discover, .other], id: \.self) {
                                Text($0.rawValue.uppercased()).tag($0)
                            }
                        }
                    }
                }

                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle(isCreditCard ? "Nueva tarjeta" : "Nueva cuenta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Guardando..." : "Guardar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .onAppear {
                if currency == "USD", let hid = appState.currentHouseholdId,
                   let h = appState.households.first(where: { $0.id == hid }) {
                    currency = h.defaultCurrency
                }
            }
        }
    }

    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        if isCreditCard {
            return (CurrencyFormatter.parse(creditLimit) ?? 0) > 0
        }
        return true
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let hid = appState.currentHouseholdId else {
            errorMessage = "Hogar no disponible"; return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let account = try await AccountService.shared.create(
                householdId: hid,
                name: name,
                type: type,
                currency: currency.uppercased(),
                startingBalance: isCreditCard ? 0 : (CurrencyFormatter.parse(initialBalance) ?? 0),
                institution: institution.isEmpty ? nil : institution
            )

            if isCreditCard {
                let details = CreditCardDetails(
                    accountId: account.id,
                    creditLimit: CurrencyFormatter.parse(creditLimit) ?? 0,
                    statementDay: statementDay,
                    dueDay: dueDay,
                    interestRateMonthly: CurrencyFormatter.parse(interestRate) ?? 0,
                    minimumPaymentPct: CurrencyFormatter.parse(minPaymentPct) ?? 5,
                    lastStatementAmount: nil,
                    lastStatementDate: nil,
                    network: network
                )
                _ = try await CreditCardService.shared.upsert(details)
            }

            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
