import SwiftUI

struct AddAccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type: AccountType = .checking
    @State private var currency = "USD"
    @State private var initialBalance = ""
    @State private var institution = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onSaved: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Básico") {
                    TextField("Nombre", text: $name)
                    Picker("Tipo", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.systemIcon).tag(type)
                        }
                    }
                    TextField("Moneda (ISO)", text: $currency)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section("Opcional") {
                    TextField("Institución (banco, billetera)", text: $institution)
                    TextField("Saldo inicial", text: $initialBalance).keyboardType(.decimalPad)
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Nueva cuenta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Guardando..." : "Guardar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || name.isEmpty)
                }
            }
        }
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
            _ = try await AccountService.shared.create(
                householdId: hid,
                name: name,
                type: type,
                currency: currency.uppercased(),
                startingBalance: CurrencyFormatter.parse(initialBalance) ?? 0,
                institution: institution.isEmpty ? nil : institution
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
