import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var transaction: Transaction
    @State private var amountStr: String
    @State private var note: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Categorías propias del hogar. Sin esto el Picker ofrecía sólo el catálogo
    /// por defecto: una categoría creada por el usuario (o puesta por el
    /// asistente) no matcheaba ninguna opción, el Picker aparecía sin selección
    /// y el primer toque la reemplazaba en silencio.
    @State private var categoriesBlob: CategoriesBlob?

    let onSaved: () async -> Void

    /// `baseCurrency` se inyecta porque el init no puede leer el `AppState` del entorno,
    /// y el monto que se edita está en moneda base.
    let baseCurrency: String

    init(transaction: Transaction, baseCurrency: String, onSaved: @escaping () async -> Void) {
        self.baseCurrency = baseCurrency
        self._transaction = State(initialValue: transaction)
        // El campo edita `amount`, que está en moneda BASE, así que se formatea con la base.
        // Antes se formateaba con `currencyOriginal`: al abrir un gasto en USD el campo mostraba
        // el monto YA CONVERTIDO con los separadores de la moneda extranjera.
        self._amountStr = State(initialValue: CurrencyFormatter.format(transaction.amount, currency: baseCurrency))
        self._note = State(initialValue: transaction.note ?? "")
        self.onSaved = onSaved
    }

    /// Catálogo del hogar (por defecto + propias) para el tipo actual, con la
    /// categoría del movimiento garantizada adentro.
    ///
    /// Ese último detalle es el que evita perder datos: si el movimiento tiene
    /// una categoría que ya no está en el catálogo —se renombró, se borró, o el
    /// blob todavía no cargó— el Picker no tendría ningún `tag` que matchee, se
    /// mostraría vacío y el primer toque la pisaría. Incluirla la deja elegible
    /// y visible aunque nadie más la use.
    private var categoriasDisponibles: [String] {
        var cats = CategoryService.merged(custom: categoriesBlob?.data, type: transaction.type)
            .map(\.name)
        if !cats.contains(transaction.category) {
            cats.insert(transaction.category, at: 0)
        }
        return cats
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("form.section.type") {
                    Picker("form.section.type", selection: $transaction.type) {
                        Text("tx.type.expense.label").tag(TxType.gasto)
                        Text("tx.type.income.label").tag(TxType.ingreso)
                    }.pickerStyle(.segmented)
                }
                Section("form.section.amount") {
                    TextField("form.field.amount", text: $amountStr).keyboardType(.decimalPad)
                }
                Section("form.section.category") {
                    Picker("form.section.category", selection: $transaction.category) {
                        ForEach(categoriasDisponibles, id: \.self) { c in
                            HStack { Text(CategoryCatalog.emoji(for: c)); Text(c) }.tag(c)
                        }
                    }
                }
                Section("form.section.dateNote") {
                    DatePicker("form.field.date", selection: $transaction.date, displayedComponents: .date)
                    TextField("form.field.note", text: $note)
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
                Section {
                    Button {
                        Task { await duplicate() }
                    } label: {
                        Label {
                            Text("tx.edit.duplicate")
                        } icon: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    .disabled(isLoading)
                    Button(role: .destructive) {
                        Task { await delete() }
                    } label: {
                        Text("tx.edit.delete")
                    }
                }
            }
            .navigationTitle(Text("tx.edit.title"))
            .task {
                // Si falla, `categoriasDisponibles` cae al catálogo por defecto
                // más la categoría actual: se puede seguir editando igual.
                categoriesBlob = try? await CategoryService.shared.fetch(
                    householdId: transaction.householdId
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? String(localized: "action.saving") : String(localized: "action.save")) {
                        Task { await submit() }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let amount = CurrencyFormatter.parse(amountStr), amount > 0 else {
            errorMessage = String(localized: "tx.edit.invalidAmount"); return
        }
        transaction.amount = amount
        transaction.note = note.isEmpty ? nil : note
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await TransactionService.shared.update(transaction)
            Haptics.play(.success)
            await onSaved()
            dismiss()
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func delete() async {
        do {
            try await TransactionService.shared.delete(id: transaction.id)
            Haptics.play(.warning)
            await onSaved()
            dismiss()
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func duplicate() async {
        errorMessage = nil
        guard let amount = CurrencyFormatter.parse(amountStr), amount > 0 else {
            errorMessage = String(localized: "tx.edit.invalidAmount"); return
        }
        isLoading = true
        defer { isLoading = false }

        let input = NewTransactionInput(
            householdId: transaction.householdId,
            userId: transaction.userId,
            accountId: transaction.accountId,
            type: transaction.type,
            amount: amount,
            // El monto editado está en moneda base, así que el duplicado nace en base con tasa 1.
            // Arrastrar `currencyOriginal` de la original acá crearía una fila inconsistente:
            // monto en base etiquetado como extranjero, que es justo el bug que se está cerrando.
            amountOriginal: amount,
            currencyOriginal: baseCurrency,
            fxRateToBase: 1,
            category: transaction.category,
            subcategory: transaction.subcategory,
            note: note.isEmpty ? nil : note,
            date: Date()
        )
        do {
            _ = try await TransactionService.shared.insert(input)
            Haptics.play(.success)
            await onSaved()
            dismiss()
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }
}
