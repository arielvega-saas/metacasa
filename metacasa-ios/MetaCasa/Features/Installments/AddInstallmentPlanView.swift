import SwiftUI

struct AddInstallmentPlanView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onSaved: () async -> Void

    @State private var name = ""
    @State private var totalAmountStr = ""
    @State private var totalInstallments = 12
    @State private var startDate = Date()
    @State private var category = ""
    @State private var note = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("installments.form.basic") {
                    TextField("installments.form.name", text: $name)
                    HStack {
                        Text("installments.form.total")
                        Spacer()
                        TextField("0", text: $totalAmountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                    Stepper(value: $totalInstallments, in: 1...120) {
                        Text("installments.form.count \(totalInstallments)")
                    }
                    DatePicker("installments.form.start", selection: $startDate, displayedComponents: .date)
                    if let perMonth = perMonth {
                        HStack {
                            Text("installments.form.perMonth")
                            Spacer()
                            AmountLabel(amount: perMonth, currency: currency, kind: .gasto)
                                .font(.body.weight(.bold))
                        }
                    }
                }
                Section("installments.form.optional") {
                    TextField("tx.field.category", text: $category)
                    TextField("tx.field.note", text: $note, axis: .vertical).lineLimit(1...3)
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle(Text("installments.form.newTitle"))
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

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private var isValid: Bool {
        !name.isEmpty && (CurrencyFormatter.parse(totalAmountStr) ?? 0) > 0 && totalInstallments > 0
    }

    private var perMonth: Decimal? {
        guard let total = CurrencyFormatter.parse(totalAmountStr), totalInstallments > 0 else { return nil }
        return total / Decimal(totalInstallments)
    }

    @MainActor
    private func save() async {
        errorMessage = nil
        guard let total = CurrencyFormatter.parse(totalAmountStr), total > 0,
              let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else {
            errorMessage = String(localized: "error.invalid_amount"); return
        }
        let comps = Calendar.current.dateComponents([.year, .month], from: startDate)
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await InstallmentService.shared.createPlan(
                userId: uid,
                householdId: hid,
                name: name,
                totalAmount: total,
                totalInstallments: totalInstallments,
                currency: currency,
                startYear: comps.year ?? 2026,
                startMonth: comps.month ?? 1,
                category: category.isEmpty ? nil : category,
                note: note.isEmpty ? nil : note
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
