import SwiftUI

struct AddGoalView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var hasTargetDate = false
    @State private var icon = "🎯"
    @State private var priority = 0
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onSaved: () async -> Void

    private let icons = ["🎯","✈️","🏠","🚗","💻","📱","🎓","💍","🏖️","🎸","🐕","🌍","🏋️","🎮","👶","🏥","🛋️","🌿","⛵"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    TextField("Nombre (ej: Viaje a Europa)", text: $name)
                    TextField("Monto objetivo", text: $targetAmount).keyboardType(.decimalPad)
                    Toggle("Con fecha objetivo", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Fecha", selection: $targetDate, displayedComponents: .date)
                    }
                }
                Section("Icono") {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(icons, id: \.self) { i in
                                Button { icon = i } label: {
                                    Text(i).font(.system(size: 24))
                                        .padding(8)
                                        .background(icon == i ? Color.brandPrimary.opacity(0.2) : Color.clear)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                Section("Prioridad") {
                    Stepper("Prioridad: \(priority)", value: $priority, in: 0...10)
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Nueva meta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Guardando..." : "Guardar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || name.isEmpty || CurrencyFormatter.parse(targetAmount) == nil)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let amount = CurrencyFormatter.parse(targetAmount), amount > 0 else {
            errorMessage = "Ingresá un monto objetivo válido"; return
        }
        guard let hid = appState.currentHouseholdId else {
            errorMessage = "Hogar no disponible"; return
        }
        let currency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await GoalService.shared.create(
                householdId: hid,
                name: name,
                targetAmount: amount,
                currency: currency,
                targetDate: hasTargetDate ? targetDate : nil,
                icon: icon,
                priority: priority
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
