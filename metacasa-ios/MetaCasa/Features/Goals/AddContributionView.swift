import SwiftUI

struct AddContributionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
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
            .navigationTitle(Text("Nuevo aporte"))
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
        guard let uid = appState.currentUserId else {
            errorMessage = "Sesión no disponible"; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let c = try await GoalService.shared.contribute(
                userId: uid,
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
