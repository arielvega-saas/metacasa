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
                Section("form.section.type") {
                    Picker("form.section.type", selection: $type) {
                        Text("tx.type.expense.label").tag(TxType.gasto)
                        Text("tx.type.income.label").tag(TxType.ingreso)
                    }
                    .pickerStyle(.segmented)
                }
                Section("form.section.amountCategory") {
                    TextField("form.field.amount", text: $amountStr).keyboardType(.decimalPad)
                    Picker("form.section.category", selection: $category) {
                        let cats = type == .gasto ? CategoryCatalog.defaultGastos : CategoryCatalog.defaultIngresos
                        ForEach(cats, id: \.self) { c in
                            HStack { Text(CategoryCatalog.emoji(for: c)); Text(c) }.tag(c)
                        }
                    }
                    TextField("form.field.noteOptional", text: $note)
                }
                Section("form.section.frequency") {
                    Picker("form.section.frequency", selection: $frequency) {
                        ForEach(Frequency.allCases, id: \.self) { f in
                            Text(f.labelKey).tag(f)
                        }
                    }
                    DatePicker("form.field.starts", selection: $startDate, displayedComponents: .date)
                    Toggle("form.field.hasEndDate", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("form.field.ends", selection: $endDate, displayedComponents: .date)
                    }
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle(Text("recurring.new"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? String(localized: "action.saving") : String(localized: "action.save")) {
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
            errorMessage = String(localized: "error.incomplete"); return
        }
        guard let uid = appState.currentUserId else {
            errorMessage = String(localized: "error.sessionUnavailable"); return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let created = try await RecurringService.shared.create(
                userId: uid,
                householdId: hid,
                type: type,
                amount: amount,
                category: category,
                frequency: frequency,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                note: note.isEmpty ? nil : note
            )
            let currency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
            if NotificationPreferences.shared.recurring {
                await NotificationService.shared.scheduleRecurringReminder(recurring: created, currency: currency)
            }
            Haptics.play(.success)
            await onSaved()
            dismiss()
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }
}
