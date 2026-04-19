import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var transaction: Transaction
    @State private var amountStr: String
    @State private var note: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onSaved: () async -> Void

    init(transaction: Transaction, onSaved: @escaping () async -> Void) {
        self._transaction = State(initialValue: transaction)
        self._amountStr = State(initialValue: CurrencyFormatter.format(transaction.amount, currency: transaction.currencyOriginal ?? "USD"))
        self._note = State(initialValue: transaction.note ?? "")
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $transaction.type) {
                        Text("Gasto").tag(TxType.gasto)
                        Text("Ingreso").tag(TxType.ingreso)
                    }.pickerStyle(.segmented)
                }
                Section("Importe") {
                    TextField("Monto", text: $amountStr).keyboardType(.decimalPad)
                }
                Section("Categoría") {
                    let cats = transaction.type == .gasto ? CategoryCatalog.defaultGastos : CategoryCatalog.defaultIngresos
                    Picker("Categoría", selection: $transaction.category) {
                        ForEach(cats, id: \.self) { c in
                            HStack { Text(CategoryCatalog.emoji(for: c)); Text(c) }.tag(c)
                        }
                    }
                }
                Section("Fecha y nota") {
                    DatePicker("Fecha", selection: $transaction.date, displayedComponents: .date)
                    TextField("Nota", text: $note)
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
                Section {
                    Button("Eliminar movimiento", role: .destructive) {
                        Task { await delete() }
                    }
                }
            }
            .navigationTitle("Editar movimiento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Guardando..." : "Guardar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let amount = CurrencyFormatter.parse(amountStr), amount > 0 else {
            errorMessage = "Monto inválido"; return
        }
        transaction.amount = amount
        transaction.note = note.isEmpty ? nil : note
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await TransactionService.shared.update(transaction)
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func delete() async {
        do {
            try await TransactionService.shared.delete(id: transaction.id)
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
