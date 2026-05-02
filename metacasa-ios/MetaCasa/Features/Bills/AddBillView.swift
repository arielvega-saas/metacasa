import SwiftUI

/// Crear o editar un vencimiento.
struct AddBillView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let editing: Bill?
    let onSaved: () async -> Void

    @State private var title: String = ""
    @State private var amountStr: String = ""
    @State private var dueDate: Date = Date()
    @State private var category: String = ""
    @State private var note: String = ""
    @State private var recurring: Bool = false
    @State private var status: BillStatus = .pending
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(editing: Bill? = nil, onSaved: @escaping () async -> Void) {
        self.editing = editing
        self.onSaved = onSaved
        if let e = editing {
            _title = State(initialValue: e.title)
            _amountStr = State(initialValue: "\(e.amount)")
            _dueDate = State(initialValue: e.dueDate)
            _category = State(initialValue: e.category ?? "")
            _note = State(initialValue: e.note ?? "")
            _recurring = State(initialValue: e.recurring)
            _status = State(initialValue: e.status)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("bills.form.basic") {
                    TextField("bills.form.title", text: $title)
                    DatePicker("tx.field.date", selection: $dueDate, displayedComponents: .date)
                    HStack {
                        Text("tx.field.amount")
                        Spacer()
                        TextField("0", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }
                Section("bills.form.optional") {
                    TextField("tx.field.category", text: $category)
                    TextField("tx.field.note", text: $note, axis: .vertical).lineLimit(1...3)
                    Toggle("bills.form.recurring", isOn: $recurring)
                }
                if editing != nil {
                    Section("bills.form.status") {
                        Picker("bills.form.status", selection: $status) {
                            Text("bills.urgency.paid").tag(BillStatus.paid)
                            Text("bills.urgency.pending").tag(BillStatus.pending)
                            Text("bills.urgency.skipped").tag(BillStatus.skipped)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle(editing == nil ? "bills.form.newTitle" : "bills.form.editTitle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "..." : String(localized: "action.save")) {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading || !isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !title.isEmpty && (CurrencyFormatter.parse(amountStr) ?? 0) > 0
    }

    @MainActor
    private func save() async {
        errorMessage = nil
        guard let amount = CurrencyFormatter.parse(amountStr), amount > 0,
              let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else {
            errorMessage = String(localized: "error.invalid_amount")
            return
        }
        let currency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
        isLoading = true
        defer { isLoading = false }
        do {
            if var edit = editing {
                edit.title = title
                edit.amount = amount
                edit.dueDate = dueDate
                edit.category = category.isEmpty ? nil : category
                edit.note = note.isEmpty ? nil : note
                edit.recurring = recurring
                edit.status = status
                let updated = try await BillService.shared.update(edit)
                if NotificationPreferences.shared.bills {
                    await NotificationService.shared.scheduleBillReminder(bill: updated)
                }
            } else {
                let created = try await BillService.shared.create(
                    userId: uid,
                    householdId: hid,
                    title: title,
                    amount: amount,
                    currency: currency,
                    dueDate: dueDate,
                    category: category.isEmpty ? nil : category,
                    note: note.isEmpty ? nil : note,
                    recurring: recurring
                )
                if NotificationPreferences.shared.bills {
                    await NotificationService.shared.scheduleBillReminder(bill: created)
                }
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
