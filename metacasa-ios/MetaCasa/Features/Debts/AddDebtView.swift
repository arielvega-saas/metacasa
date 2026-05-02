import SwiftUI

struct AddDebtView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let editing: Debt?
    let onSaved: () async -> Void

    @State private var creditor = ""
    @State private var originalAmountStr = ""
    @State private var currentBalanceStr = ""
    @State private var annualRateStr = ""
    @State private var monthlyPaymentStr = ""
    @State private var startDate = Date()
    @State private var maturityDate = Date()
    @State private var hasMaturity = false
    @State private var category = ""
    @State private var note = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(editing: Debt? = nil, onSaved: @escaping () async -> Void) {
        self.editing = editing
        self.onSaved = onSaved
        if let e = editing {
            _creditor = State(initialValue: e.creditor)
            _originalAmountStr = State(initialValue: "\(e.originalAmount)")
            _currentBalanceStr = State(initialValue: "\(e.currentBalance)")
            _annualRateStr = State(initialValue: "\(e.annualRate)")
            _monthlyPaymentStr = State(initialValue: e.monthlyPayment.map { "\($0)" } ?? "")
            _startDate = State(initialValue: e.startDate)
            _maturityDate = State(initialValue: e.maturityDate ?? Date())
            _hasMaturity = State(initialValue: e.maturityDate != nil)
            _category = State(initialValue: e.category ?? "")
            _note = State(initialValue: e.note ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("debts.form.basic") {
                    TextField("debts.form.creditor", text: $creditor)
                    HStack {
                        Text("debts.form.originalAmount")
                        Spacer()
                        TextField("0", text: $originalAmountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 140)
                    }
                    HStack {
                        Text("debts.form.currentBalance")
                        Spacer()
                        TextField("0", text: $currentBalanceStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 140)
                    }
                }
                Section("debts.form.interest") {
                    HStack {
                        Text("debts.form.annualRate")
                        Spacer()
                        TextField("0", text: $annualRateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 100)
                        Text("%").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("debts.form.monthlyPayment")
                        Spacer()
                        TextField("0", text: $monthlyPaymentStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 140)
                    }
                }
                Section("debts.form.dates") {
                    DatePicker("debts.form.start", selection: $startDate, displayedComponents: .date)
                    Toggle("debts.form.hasMaturity", isOn: $hasMaturity)
                    if hasMaturity {
                        DatePicker("debts.form.maturity", selection: $maturityDate, displayedComponents: .date)
                    }
                }
                Section("bills.form.optional") {
                    TextField("tx.field.category", text: $category)
                    TextField("tx.field.note", text: $note, axis: .vertical).lineLimit(1...3)
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle(editing == nil ? "debts.form.newTitle" : "debts.form.editTitle")
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
        !creditor.isEmpty && (CurrencyFormatter.parse(originalAmountStr) ?? 0) > 0
    }

    @MainActor
    private func save() async {
        errorMessage = nil
        guard let orig = CurrencyFormatter.parse(originalAmountStr),
              let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else {
            errorMessage = String(localized: "error.invalid_amount"); return
        }
        let balance = CurrencyFormatter.parse(currentBalanceStr) ?? orig
        let rate = CurrencyFormatter.parse(annualRateStr) ?? 0
        let monthly = CurrencyFormatter.parse(monthlyPaymentStr)
        let currency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
        isLoading = true
        defer { isLoading = false }
        do {
            if var edit = editing {
                edit.creditor = creditor
                edit.currentBalance = balance
                edit.annualRate = rate
                edit.monthlyPayment = monthly
                edit.maturityDate = hasMaturity ? maturityDate : nil
                edit.category = category.isEmpty ? nil : category
                edit.note = note.isEmpty ? nil : note
                _ = try await DebtService.shared.update(edit)
            } else {
                _ = try await DebtService.shared.create(
                    userId: uid,
                    householdId: hid,
                    creditor: creditor,
                    originalAmount: orig,
                    currentBalance: balance,
                    annualRate: rate,
                    monthlyPayment: monthly,
                    currency: currency,
                    startDate: startDate,
                    maturityDate: hasMaturity ? maturityDate : nil,
                    category: category.isEmpty ? nil : category,
                    note: note.isEmpty ? nil : note
                )
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
