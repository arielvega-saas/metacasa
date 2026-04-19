import SwiftUI

struct AddContributionView: View {
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    let onSaved: (GoalContribution) async -> Void

    @State private var amount = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto a aportar (\(goal.currency))") {
                    TextField("0", text: $amount)
                        .keyboardType(.decimalPad)
                }
                Section("Nota") {
                    TextField("Opcional", text: $notes)
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Nuevo aporte")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Guardando..." : "Guardar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || CurrencyFormatter.parse(amount) == nil)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let amt = CurrencyFormatter.parse(amount), amt > 0 else {
            errorMessage = "Monto inválido"; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let c = try await GoalService.shared.contribute(
                goalId: goal.id,
                amount: amt,
                notes: notes.isEmpty ? nil : notes
            )
            await onSaved(c)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
