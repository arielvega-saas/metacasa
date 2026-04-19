import SwiftUI

struct AddRecurringView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var type: TxType = .gasto
    @State private var amountStr = ""
    @State private var category = "Servicios"
    @State private var note = ""
    @State private var frequency: Frequency = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onSaved: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        Text("Gasto").tag(TxType.gasto)
                        Text("Ingreso").tag(TxType.ingreso)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Importe y categoría") {
                    TextField("Monto", text: $amountStr).keyboardType(.decimalPad)
                    Picker("Categoría", selection: $category) {
                        let cats = type == .gasto ? CategoryCatalog.defaultGastos : CategoryCatalog.defaultIngresos
                        ForEach(cats, id: \.self) { c in
                            HStack { Text(CategoryCatalog.emoji(for: c)); Text(c) }.tag(c)
                        }
                    }
                    TextField("Nota (opcional)", text: $note)
                }
                Section("Frecuencia") {
                    Picker("Frecuencia", selection: $frequency) {
                        ForEach(Frequency.allCases, id: \.self) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    DatePicker("Empieza", selection: $startDate, displayedComponents: .date)
                    Toggle("Con fecha de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Termina", selection: $endDate, displayedComponents: .date)
                    }
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Nuevo recurrente")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Guardando..." : "Guardar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || CurrencyFormatter.parse(amountStr) == nil)
                }
            }
            .onChange(of: type) { _, new in
                let cats = new == .gasto ? CategoryCatalog.defaultGastos : CategoryCatalog.defaultIngresos
                if !cats.contains(category) { category = cats.first ?? "" }
            }
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let hid = appState.currentHouseholdId,
              let amount = CurrencyFormatter.parse(amountStr), amount > 0
        else {
            errorMessage = "Datos incompletos"; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await RecurringService.shared.create(
                householdId: hid,
                type: type,
                amount: amount,
                category: category,
                frequency: frequency,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                note: note.isEmpty ? nil : note
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
