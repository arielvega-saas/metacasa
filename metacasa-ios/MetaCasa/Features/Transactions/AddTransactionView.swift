import SwiftUI

struct AddTransactionView: View {
    @Environment(AppState.self) private var appState
    @State private var type: TxType = .gasto
    @State private var amountStr = ""
    @State private var category = "Alimentación"
    @State private var note = ""
    @State private var date = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        typeToggle
                        amountField
                        categoryPicker
                        notesField
                        dateField
                        if let msg = errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(Color.brandDanger)
                        }
                        Button {
                            Task { await submit() }
                        } label: {
                            Text(isLoading ? "Guardando..." : "Guardar \(type.label.lowercased())")
                        }
                        .buttonStyle(MCPrimaryButton())
                        .disabled(isLoading || parseAmount() == nil)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Nuevo movimiento")
            .onChange(of: type) { _, newValue in
                let cats = newValue == .gasto ? CategoryCatalog.defaultGastos : CategoryCatalog.defaultIngresos
                if !cats.contains(category) { category = cats.first ?? "" }
            }
            .alert("Guardado ✓", isPresented: $showSuccess) {
                Button("OK") { reset() }
            }
        }
    }

    private var typeToggle: some View {
        Picker("Tipo", selection: $type) {
            Text("Gasto").tag(TxType.gasto)
            Text("Ingreso").tag(TxType.ingreso)
        }
        .pickerStyle(.segmented)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MONTO").font(.mcLabel).foregroundStyle(Color.textMuted)
            TextField("0", text: $amountStr)
                .keyboardType(.decimalPad)
                .font(.mcDisplay)
                .foregroundStyle(type == .gasto ? Color.brandDanger : Color.brandSuccess)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CATEGORÍA").font(.mcLabel).foregroundStyle(Color.textMuted)
            let cats = type == .gasto ? CategoryCatalog.defaultGastos : CategoryCatalog.defaultIngresos
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cats, id: \.self) { cat in
                        Button { category = cat } label: {
                            HStack(spacing: 6) {
                                Text(CategoryCatalog.emoji(for: cat))
                                Text(cat).font(.mcCaption.weight(.bold))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(category == cat ? Color.brandPrimary : Color.appSurface)
                            .foregroundStyle(category == cat ? Color.white : Color.textPrimary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTA").font(.mcLabel).foregroundStyle(Color.textMuted)
            TextField("Opcional", text: $note)
                .font(.mcBody)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FECHA").font(.mcLabel).foregroundStyle(Color.textMuted)
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(.brandPrimary)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func parseAmount() -> Decimal? {
        let d = CurrencyFormatter.parse(amountStr)
        return (d ?? 0) > 0 ? d : nil
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let amount = parseAmount() else {
            errorMessage = "Ingresá un monto válido"
            return
        }
        guard let hid = appState.currentHouseholdId, let uid = appState.currentUserId else {
            errorMessage = "Hogar no disponible"
            return
        }
        isLoading = true
        defer { isLoading = false }

        let input = NewTransactionInput(
            householdId: hid,
            userId: uid,
            accountId: nil,
            type: type,
            amount: amount,
            currencyOriginal: nil,
            category: category,
            subcategory: nil,
            note: note.isEmpty ? nil : note,
            date: date
        )
        do {
            _ = try await TransactionService.shared.insert(input)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reset() {
        amountStr = ""
        note = ""
        date = Date()
    }
}
