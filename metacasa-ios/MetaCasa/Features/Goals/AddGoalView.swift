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
                Section("form.section.data") {
                    TextField("form.field.goalName", text: $name)
                    TextField("form.field.goalTarget", text: $targetAmount).keyboardType(.decimalPad)
                    Toggle("form.field.hasTargetDate", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("form.field.date", selection: $targetDate, displayedComponents: .date)
                    }
                }
                Section("form.section.icon") {
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
                Section("form.section.priority") {
                    Stepper(value: $priority, in: 0...10) {
                        Text("form.priority.format \(priority)")
                    }
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
            }
            .navigationTitle(Text("goal.new"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? String(localized: "action.saving") : String(localized: "action.save")) {
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
            errorMessage = String(localized: "goal.invalidAmount"); return
        }
        guard let hid = appState.currentHouseholdId else {
            errorMessage = String(localized: "goal.householdMissing"); return
        }
        guard let uid = appState.currentUserId else {
            errorMessage = String(localized: "error.sessionUnavailable"); return
        }
        let currency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
        isLoading = true
        defer { isLoading = false }
        do {
            let created = try await GoalService.shared.create(
                userId: uid,
                householdId: hid,
                name: name,
                targetAmount: amount,
                currency: currency,
                targetDate: hasTargetDate ? targetDate : nil,
                icon: icon,
                priority: priority
            )
            if NotificationPreferences.shared.goals {
                await NotificationService.shared.scheduleGoalReminder(goal: created)
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
