import SwiftUI

struct AddTransactionView: View {
    @Environment(AppState.self) private var appState
    @State private var type: TxType = .gasto
    @State private var amountStr = ""
    @State private var category = "Alimentación"
    @State private var subcategory: String? = nil
    @State private var note = ""
    @State private var date = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    // Categories blob (para subcategorías)
    @State private var categoriesBlob: CategoriesBlob?

    // Templates (quick shortcuts)
    @State private var templates: [TransactionTemplate] = []
    @State private var showSaveTemplate = false
    @State private var newTemplateName = ""

    // Multi-moneda inline (Sprint 9)
    @State private var useAlternateCurrency = false
    @State private var alternateCurrency: String = "USD"
    @State private var fxRateStr: String = ""
    @State private var knownFxRates: [String: Decimal] = [:]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        shortcutsBar
                        typeToggle
                        amountField
                        currencyToggleField
                        categoryPicker
                        notesField
                        dateField
                        if let msg = errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(Color.brandDanger)
                        }

                        if parseAmount() != nil {
                            Button {
                                newTemplateName = "\(category)"
                                showSaveTemplate = true
                            } label: {
                                Label {
                                    Text("shortcuts.saveCurrent")
                                } icon: {
                                    Image(systemName: "bookmark")
                                }
                                .font(.caption)
                                .foregroundStyle(Color.brandPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)   // espacio para el sticky save bar
                }

                stickySaveBar
            }
            .navigationTitle(Text("tx.new"))
            .task {
                await loadTemplates()
                await loadCategoriesBlob()
                await loadFxRates()
            }
            .alert("shortcuts.saveTitle", isPresented: $showSaveTemplate) {
                TextField("shortcuts.namePlaceholder", text: $newTemplateName)
                Button("action.cancel", role: .cancel) {}
                Button("action.save") {
                    Task { await saveCurrentAsTemplate() }
                }
            } message: {
                Text("shortcuts.saveHint")
            }
            .onChange(of: type) { _, newValue in
                let cats = newValue == .gasto ? CategoryCatalog.defaultGastos : CategoryCatalog.defaultIngresos
                if !cats.contains(category) { category = cats.first ?? "" }
                subcategory = nil
            }
            .onChange(of: category) { _, _ in
                subcategory = nil
            }
            .alert("tx.saved", isPresented: $showSuccess) {
                Button("OK") { reset() }
            }
        }
    }

    private var typeToggle: some View {
        HStack(spacing: 10) {
            typePill(kind: .gasto,   icon: "arrow.down", label: "tx.type.expense", color: .brandDanger)
            typePill(kind: .ingreso, icon: "arrow.up",   label: "tx.type.income",  color: .brandSuccess)
        }
    }

    private func typePill(kind: TxType, icon: String, label: LocalizedStringKey, color: Color) -> some View {
        let isSelected = type == kind
        return Button {
            Haptics.play(.selection)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                type = kind
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.subheadline.weight(.bold))
                Text(label).font(.mcBody.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color(hex: "#0E1312") : Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? color.opacity(0.6) : Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? color : Color.appBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .pressableScale(0.97)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label con el currency code visible.
            HStack {
                Text("tx.field.amount").font(.mcLabel).foregroundStyle(Color.textMuted)
                Spacer()
                Text(householdCurrency)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.appSurfaceInset)
                    .clipShape(Capsule())
            }

            // Card del monto: serif hero + gradiente sage→champagne + glow al
            // tener un valor positivo. El monto es el "héroe" del flow.
            HStack(spacing: 8) {
                Text(currencySymbol)
                    .font(.mcSerifDisplay)
                    .foregroundStyle(amountColor)

                TextField("0", text: $amountStr)
                    .keyboardType(.decimalPad)
                    .font(.mcSerifHero)
                    .foregroundStyle(amountColor)
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.brandPrimary.opacity(0.10), Color.brandSecondary.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .glowIfPositive((parseAmount() ?? 0) > 0, radius: 20)
            .opacity(amountStr.isEmpty ? 0.65 : 1)
            .animation(.easeOut(duration: 0.3), value: amountStr.isEmpty)

            // Quick amounts: shortcuts +1k / +5k / +10k / +50k / Limpiar
            HStack(spacing: 8) {
                ForEach([1000, 5000, 10000, 50000], id: \.self) { v in
                    quickAmountChip(v)
                }
                quickClearChip
            }

            // Preview en tiempo real con puntos de miles + símbolo moneda.
            if let amount = parseAmount() {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandSuccess)
                    Text("form.amount.preview \(Money.format(amount, currency: householdCurrency, style: .auto))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 4)
                .animation(.easeOut(duration: 0.15), value: amount)
            }
        }
    }

    private var amountColor: Color {
        if amountStr.isEmpty { return Color.textDim }
        return type == .gasto ? Color.brandDanger : Color.brandSuccess
    }

    private func quickAmountChip(_ value: Int) -> some View {
        Button {
            let cur = parseAmount() ?? 0
            let new = cur + Decimal(value)
            // "1000.0" → "1000". Mantenemos decimales si los había.
            var str = "\(new)"
            if str.hasSuffix(".0") { str = String(str.dropLast(2)) }
            amountStr = str
            Haptics.play(.impactLight)
        } label: {
            Text("+\(value.formatted(.number.notation(.compactName)))")
                .font(.mcCaption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Color.appSurface))
                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pressableScale(0.96)
    }

    private var quickClearChip: some View {
        Button {
            amountStr = ""
            Haptics.play(.selection)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark").font(.caption2.weight(.bold))
                Text("Limpiar").font(.mcCaption.weight(.semibold))
            }
            .foregroundStyle(Color.brandDanger)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(Color.brandDanger.opacity(0.10)))
            .overlay(Capsule().stroke(Color.brandDanger.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pressableScale(0.96)
    }

    /// Sticky save bar al fondo del view. Background sólido + divider + shadow
    /// superior para separarlo visualmente del scroll content.
    private var stickySaveBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.appBorder.opacity(0.5))
            Button {
                Task { await submit() }
            } label: {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Label {
                        Text(type == .gasto ? "tx.button.save_expense" : "tx.button.save_income")
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .buttonStyle(MCPrimaryButton())
            .disabled(isLoading || parseAmount() == nil)
            .opacity(parseAmount() == nil ? 0.55 : 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.appSurface.shadow(.drop(color: .black.opacity(0.08), radius: 12, y: -4)))
    }

    /// Moneda del hogar activo (cae a USD si no hay).
    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    /// Símbolo de la moneda actual según locale (US$, $, €, R$, etc.).
    private var currencySymbol: String {
        let loc = AppLocaleStorage.effectiveLocale
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = effectiveCurrency
        formatter.locale = loc
        return formatter.currencySymbol ?? effectiveCurrency
    }

    /// Moneda efectiva (la alternativa si el toggle está on, sino la del hogar).
    private var effectiveCurrency: String {
        useAlternateCurrency ? alternateCurrency : householdCurrency
    }

    /// Tasa de cambio parseada, o la conocida, o 1.
    private var effectiveFxRate: Decimal {
        if let parsed = CurrencyFormatter.parse(fxRateStr), parsed > 0 {
            return parsed
        }
        if useAlternateCurrency, let known = knownFxRates[alternateCurrency] {
            return known
        }
        return 1
    }

    /// Monto convertido a moneda base del hogar (si aplica).
    private var convertedAmount: Decimal? {
        guard useAlternateCurrency, alternateCurrency != householdCurrency,
              let amt = parseAmount() else { return nil }
        return amt * effectiveFxRate
    }

    /// Row expandible: "Usar otra moneda" → si on, muestra picker + fxRate.
    @ViewBuilder
    private var currencyToggleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $useAlternateCurrency.animation(.easeOut(duration: 0.2))) {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.arrow.circlepath")
                        .foregroundStyle(Color.brandPrimary)
                    Text("tx.useAlternateCurrency")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .tint(.brandPrimary)

            if useAlternateCurrency {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("tx.currency").font(.caption.weight(.bold)).foregroundStyle(Color.textMuted)
                        Spacer()
                        Menu {
                            ForEach(commonCurrencies, id: \.self) { code in
                                Button {
                                    alternateCurrency = code
                                    if let known = knownFxRates[code] {
                                        fxRateStr = "\(known)"
                                    }
                                } label: {
                                    Label(code, systemImage: alternateCurrency == code ? "checkmark" : "")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(alternateCurrency).font(.subheadline.weight(.bold))
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                            .foregroundStyle(Color.brandPrimary)
                        }
                    }

                    HStack {
                        Text("tx.fxRate").font(.caption.weight(.bold)).foregroundStyle(Color.textMuted)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("1 \(alternateCurrency) =")
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.textMuted)
                            TextField("0", text: $fxRateStr)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                .font(.subheadline.weight(.semibold))
                            Text(householdCurrency)
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.textMuted)
                        }
                    }

                    if let conv = convertedAmount {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .foregroundStyle(Color.brandSuccess)
                                .font(.caption)
                            Text("tx.convertedPreview \(Money.format(conv, currency: householdCurrency, style: .auto))")
                                .font(.caption.weight(.semibold))
                                .contentTransition(.numericText())
                        }
                        .padding(.top, 2)
                    } else if parseAmount() != nil {
                        Text("tx.fxRateHint")
                            .font(.caption2)
                            .foregroundStyle(Color.textMuted)
                    }
                }
                .padding(14)
                .background(Color.appSurfaceInset)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private let commonCurrencies = ["USD", "EUR", "ARS", "BRL", "MXN", "CLP", "UYU", "COP", "PEN", "GBP"]

    @MainActor
    private func loadFxRates() async {
        guard let hid = appState.currentHouseholdId else { return }
        let rates = (try? await FXService.shared.fetch(householdId: hid)) ?? [:]
        var dict: [String: Decimal] = [:]
        for (code, rate) in rates {
            dict[code] = rate.rate
        }
        knownFxRates = dict
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tx.field.category").font(.mcLabel).foregroundStyle(Color.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableCategoryItems, id: \.name) { cat in
                        MCChip(
                            icon: cat.emoji ?? CategoryCatalog.emoji(for: cat.name),
                            label: cat.name,
                            isSelected: category == cat.name,
                            action: {
                                category = cat.name
                            }
                        )
                    }
                }
                .padding(.horizontal, 1)  // espacio para que el border 1.5pt del selected no se recorte
            }

            // Subcategorías (si la categoría tiene definidas)
            if !availableSubcategories.isEmpty {
                Text("tx.field.subcategory")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.textMuted)
                    .textCase(.uppercase)
                    .padding(.top, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        MCChip(
                            icon: nil,
                            label: String(localized: "tx.field.subcategory.none"),
                            isSelected: subcategory == nil,
                            action: { subcategory = nil }
                        )
                        ForEach(availableSubcategories, id: \.self) { sub in
                            MCChip(
                                icon: nil,
                                label: sub,
                                isSelected: subcategory == sub,
                                action: { subcategory = sub }
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    /// Lista de categorías disponibles según type (mergea defaults + custom del hogar).
    private var availableCategoryItems: [CategoryItem] {
        CategoryService.merged(custom: categoriesBlob?.data, type: type)
    }

    /// Subcategorías definidas en el CategoriesBlob para la categoría actual.
    private var availableSubcategories: [String] {
        availableCategoryItems.first(where: { $0.name == category })?.subcategories ?? []
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("tx.field.note").font(.mcLabel).foregroundStyle(Color.textMuted)
            TextField(String(localized: "tx.note.placeholder"), text: $note)
                .font(.mcBody)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            categorySuggestionStrip
        }
    }

    /// Strip horizontal de sugerencias de categoría basadas en el texto de
    /// la nota. Aparece solo si (a) hay ≥2 caracteres tipeados, (b) al menos
    /// 1 sugerencia matchea Y (c) la categoría sugerida es distinta de la
    /// actualmente seleccionada. 1-tap cambia `category` a la sugerida.
    @ViewBuilder
    private var categorySuggestionStrip: some View {
        let suggestions = computeCategorySuggestions()
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Label("tx.category.suggest", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                    ForEach(suggestions, id: \.category) { s in
                        Button {
                            Haptics.play(.selection)
                            category = s.category
                        } label: {
                            Text(s.category)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.brandPrimary.opacity(0.15))
                                .foregroundStyle(Color.brandPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .transition(.opacity)
        }
    }

    private func computeCategorySuggestions() -> [CategorySuggester.Suggestion] {
        guard note.count >= 2 else { return [] }
        let known = availableCategoryItems.map(\.name)
        return CategorySuggester.suggest(
            input: note,
            type: type,
            known: known,
            limit: 3
        ).filter { $0.category != category }   // No mostrar la que ya está seleccionada
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("tx.field.date").font(.mcLabel).foregroundStyle(Color.textMuted)
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
            errorMessage = String(localized: "error.invalid_amount")
            return
        }
        guard let hid = appState.currentHouseholdId, let uid = appState.currentUserId else {
            errorMessage = String(localized: "error.household_missing")
            return
        }
        isLoading = true
        defer { isLoading = false }

        let input = NewTransactionInput(
            householdId: hid,
            userId: uid,
            accountId: nil,
            type: type,
            amount: useAlternateCurrency ? (convertedAmount ?? amount) : amount,
            currencyOriginal: useAlternateCurrency ? alternateCurrency : nil,
            category: category,
            subcategory: subcategory,
            note: note.isEmpty ? nil : note,
            date: date
        )
        do {
            _ = try await TransactionService.shared.insert(input)
            Haptics.play(.success)
            showSuccess = true
            // Donamos el intent al sistema para que iOS aprenda y sugiera
            // "Cargar gasto" en la Search / Lock Screen cuando el user
            // tenga ese patrón (ej: tarde/noche después de cenar).
            Task { await IntentDonations.donateAddExpense() }
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }

    private func reset() {
        amountStr = ""
        note = ""
        date = Date()
        subcategory = nil
    }

    // MARK: - Shortcuts

    /// Barra horizontal con templates + acción "nuevo".
    @ViewBuilder
    private var shortcutsBar: some View {
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("shortcuts.title")
                    .font(.mcLabel)
                    .foregroundStyle(Color.textMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates) { template in
                            shortcutChip(template)
                        }
                    }
                }
            }
        }
    }

    private func shortcutChip(_ t: TransactionTemplate) -> some View {
        Button {
            apply(template: t)
        } label: {
            HStack(spacing: 6) {
                if let e = t.emoji { Text(e) }
                VStack(alignment: .leading, spacing: 0) {
                    Text(t.name).font(.caption.weight(.semibold))
                    Text(Money.format(t.amount, currency: t.currency, style: .compact))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(t.type == .gasto ? Color.brandDanger.opacity(0.12) : Color.brandSuccess.opacity(0.12))
            .foregroundStyle(t.type == .gasto ? Color.brandDanger : Color.brandSuccess)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await delete(template: t) }
            } label: {
                Label("action.delete", systemImage: "trash")
            }
        }
    }

    private func apply(template t: TransactionTemplate) {
        type = t.type
        amountStr = "\(t.amount)"
        category = t.category
        subcategory = t.subcategory
        note = t.note ?? ""
    }

    @MainActor
    private func loadTemplates() async {
        guard let hid = appState.currentHouseholdId else { return }
        templates = (try? await TemplateService.shared.fetchAll(householdId: hid)) ?? []
    }

    @MainActor
    private func loadCategoriesBlob() async {
        guard let hid = appState.currentHouseholdId else { return }
        categoriesBlob = try? await CategoryService.shared.fetch(householdId: hid)
    }

    @MainActor
    private func saveCurrentAsTemplate() async {
        guard let amount = parseAmount(),
              let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId,
              !newTemplateName.isEmpty else { return }
        let currency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
        let emoji = CategoryCatalog.emoji(for: category)
        do {
            _ = try await TemplateService.shared.create(
                userId: uid,
                householdId: hid,
                name: newTemplateName,
                emoji: emoji,
                type: type,
                amount: amount,
                currency: currency,
                category: category,
                subcategory: subcategory,
                note: note.isEmpty ? nil : note,
                position: templates.count
            )
            await loadTemplates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func delete(template: TransactionTemplate) async {
        try? await TemplateService.shared.delete(id: template.id)
        await loadTemplates()
    }
}
