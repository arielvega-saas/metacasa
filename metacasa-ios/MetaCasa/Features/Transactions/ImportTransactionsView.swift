import SwiftUI
import UniformTypeIdentifiers

/// Flujo de import de transacciones desde CSV.
///
/// UX:
///   1. Usuario tapea botón → file picker (`.fileImporter`) acepta `.csv`.
///   2. Leemos el texto, parseamos con `TransactionCSVImporter`, autodetectamos
///      el mapping de columnas.
///   3. Mostramos preview: header + mapping editable + primeras 10 filas +
///      conteo de válidas/duplicadas/errores.
///   4. Usuario ajusta mapping si hace falta y confirma.
///   5. Generamos `NewTransactionInput[]` y los insertamos secuencialmente.
///   6. Reportamos éxito + count insertado, y llamamos `onFinish()` para que
///      el caller recargue la lista.
@MainActor
struct ImportTransactionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onFinish: () async -> Void

    @State private var showPicker = true
    @State private var csvText: String?
    @State private var parsed: ParsedImport?
    @State private var existing: [Transaction] = []
    @State private var isImporting = false
    @State private var insertedCount: Int?
    @State private var errorMessage: String?
    /// IDs de rows marcadas como duplicate que el user quiere importar igual.
    @State private var forceImportDups: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if parsed == nil {
                    pickerState
                } else if let done = insertedCount {
                    successState(count: done)
                } else if let parsed {
                    previewState(parsed: parsed)
                }
            }
            .navigationTitle(Text("import.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText, .init(filenameExtension: "csv")].compactMap { $0 },
                allowsMultipleSelection: false
            ) { result in
                handlePicker(result: result)
            }
            .task {
                // Traer transacciones existentes para dedupe (últimos 365 días)
                if let hid = appState.currentHouseholdId {
                    let now = Date()
                    let cal = Calendar.current
                    let start = cal.date(byAdding: .day, value: -365, to: now) ?? now
                    existing = (try? await TransactionService.shared.fetchForPeriod(
                        householdId: hid, from: start, to: now, limit: 5000
                    )) ?? []
                }
            }
        }
    }

    // MARK: - States

    private var pickerState: some View {
        ContentUnavailableView {
            Label("import.pick.title", systemImage: "tray.and.arrow.down")
        } description: {
            Text("import.pick.description")
        } actions: {
            Button {
                showPicker = true
            } label: {
                Label("import.pick.action", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func previewState(parsed: ParsedImport) -> some View {
        Form {
            // Resumen
            Section {
                summaryCard(parsed: parsed)
            }

            // Mapping editable
            Section("import.mapping") {
                ForEach(parsed.headers.indices, id: \.self) { i in
                    HStack {
                        Text(parsed.headers[i])
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { parsed.mapping[i] },
                            set: { newValue in updateMapping(at: i, to: newValue) }
                        )) {
                            ForEach(TxField.allCases) { field in
                                Text(field.label).tag(field)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            // Preview filas
            Section("import.preview") {
                ForEach(parsed.rows.prefix(10)) { row in
                    previewRow(row)
                }
                if parsed.rows.count > 10 {
                    Text("+ \(parsed.rows.count - 10) filas más")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // Errores
            let errorRows = parsed.rows.filter { !$0.isValid }
            if !errorRows.isEmpty {
                Section {
                    DisclosureGroup("import.errors \(errorRows.count)") {
                        ForEach(errorRows) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Línea \(row.lineNumber)").font(.caption.bold())
                                ForEach(row.issues, id: \.self) { issue in
                                    Text("• \(issue)")
                                        .font(.caption)
                                        .foregroundStyle(Color.brandDanger)
                                }
                            }
                        }
                    }
                }
            }

            // Duplicados con merge UI: el user puede forzar import de algunos.
            let dupRows = parsed.rows.filter { $0.isDuplicate && $0.isValid }
            if !dupRows.isEmpty {
                Section {
                    HStack {
                        Button {
                            forceImportDups = Set(dupRows.map(\.id))
                        } label: {
                            Label("import.duplicates.importAll", systemImage: "tray.and.arrow.down")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button {
                            forceImportDups = []
                        } label: {
                            Label("import.duplicates.skipAll", systemImage: "hand.raised")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                    DisclosureGroup("import.duplicates.review \(dupRows.count)") {
                        ForEach(dupRows) { row in
                            duplicateRow(row)
                        }
                    }
                } header: {
                    Label("import.duplicates.section", systemImage: "doc.on.doc.fill")
                        .foregroundStyle(Color.brandWarning)
                } footer: {
                    Text("import.duplicates.hint")
                }
            }

            // Acción
            Section {
                Button {
                    Task { await commitImport() }
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView().tint(.primary)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("import.commit \(effectiveCommitCount(parsed: parsed))")
                    }
                }
                .disabled(isImporting || effectiveCommitCount(parsed: parsed) == 0)
            }

            if let msg = errorMessage {
                Section {
                    Text(msg).foregroundStyle(Color.brandDanger)
                }
            }
        }
    }

    private func successState(count: Int) -> some View {
        ContentUnavailableView {
            Label("import.success", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.brandSuccess)
        } description: {
            Text("import.success.count \(count)")
        } actions: {
            Button("action.close") {
                Task {
                    await onFinish()
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Summary

    private func summaryCard(parsed: ParsedImport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.brandSuccess)
                Text("\(parsed.validCount) válidas")
                Spacer()
            }
            if parsed.duplicateCount > 0 {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(Color.brandWarning)
                    Text("\(parsed.duplicateCount) duplicadas (se saltean)")
                    Spacer()
                }
            }
            if parsed.errorCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.brandDanger)
                    Text("\(parsed.errorCount) con errores (se saltean)")
                    Spacer()
                }
            }
        }
        .font(.caption)
    }

    // MARK: - Preview row

    private func previewRow(_ row: ParsedImportRow) -> some View {
        HStack {
            statusIcon(row)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if let d = row.date {
                        Text(d, format: .dateTime.day().month(.abbreviated))
                            .font(.caption.bold())
                    }
                    Text(row.category ?? "—").font(.caption)
                    Spacer()
                }
                if let note = row.note {
                    Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if let amount = row.amount, let type = row.type {
                Text(Money.format(
                    type == .gasto ? -amount : amount,
                    currency: row.currency ?? (appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"),
                    style: .compact
                ))
                .font(.caption.bold())
                .foregroundStyle(type == .gasto ? Color.brandDanger : Color.brandSuccess)
            }
        }
    }

    private func statusIcon(_ row: ParsedImportRow) -> some View {
        Group {
            if !row.isValid {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.brandDanger)
            } else if row.isDuplicate {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(Color.brandWarning)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.brandSuccess)
            }
        }
        .font(.caption)
    }

    /// Row para un duplicado con toggle "importar igual".
    private func duplicateRow(_ row: ParsedImportRow) -> some View {
        let willImport = forceImportDups.contains(row.id)
        return HStack(spacing: 10) {
            Image(systemName: willImport ? "tray.and.arrow.down.fill" : "doc.on.doc")
                .foregroundStyle(willImport ? Color.brandSuccess : Color.brandWarning)
                .font(.callout)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if let d = row.date {
                        Text(d, format: .dateTime.day().month(.abbreviated).year())
                            .font(.caption.bold())
                    }
                    Text(row.category ?? "—").font(.caption)
                    Spacer()
                    if let amt = row.amount {
                        Text(Money.format(amt, currency: row.currency ?? "USD", style: .compact))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(row.type == .gasto ? Color.brandDanger : Color.brandSuccess)
                    }
                }
                if let note = row.note, !note.isEmpty {
                    Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(willImport ? "import.duplicates.willImport" : "import.duplicates.willSkip")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(willImport ? Color.brandSuccess : Color.textMuted)
            }
            Toggle("", isOn: Binding(
                get: { willImport },
                set: { new in
                    Haptics.play(.selection)
                    if new { forceImportDups.insert(row.id) } else { forceImportDups.remove(row.id) }
                }
            ))
            .labelsHidden()
            .tint(.brandPrimary)
        }
    }

    /// Count efectivo que se va a importar considerando forceImportDups.
    private func effectiveCommitCount(parsed: ParsedImport) -> Int {
        parsed.rows.filter { row in
            row.isValid && (!row.isDuplicate || forceImportDups.contains(row.id))
        }.count
    }

    // MARK: - Actions

    private func handlePicker(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // `.task` puede no haber terminado aún (network). Disparamos la
            // carga de existing + parse adentro del picker para garantizar
            // que el dedupe SIEMPRE se ejecuta con datos.
            Task { @MainActor in
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    csvText = text

                    if existing.isEmpty, let hid = appState.currentHouseholdId {
                        let cal = Calendar.current
                        let start = cal.date(byAdding: .day, value: -365, to: Date()) ?? Date()
                        existing = (try? await TransactionService.shared.fetchForPeriod(
                            householdId: hid, from: start, to: Date(), limit: 5000
                        )) ?? []
                    }
                    parsed = TransactionCSVImporter.parse(text: text, existing: existing)
                } catch {
                    errorMessage = "No se pudo leer el archivo: \(error.localizedDescription)"
                }
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func updateMapping(at index: Int, to field: TxField) {
        guard var parsed, let text = csvText else { return }
        var newMapping = parsed.mapping
        guard index < newMapping.count else { return }
        newMapping[index] = field
        parsed = TransactionCSVImporter.applyMapping(
            newMapping,
            to: parsed,
            text: text,
            existing: existing
        )
        self.parsed = parsed
    }

    @MainActor
    private func commitImport() async {
        guard let parsed else { return }
        guard let hid = appState.currentHouseholdId else {
            errorMessage = String(localized: "error.household_missing")
            return
        }
        guard let uid = appState.currentUserId else {
            errorMessage = String(localized: "error.session_missing")
            return
        }
        let defaultCurrency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
        let inputs = TransactionCSVImporter.buildInputs(
            from: parsed,
            householdId: hid,
            userId: uid,
            defaultCurrency: defaultCurrency,
            forceImportDuplicates: forceImportDups
        )

        isImporting = true
        defer { isImporting = false }

        var inserted = 0
        for input in inputs {
            do {
                _ = try await TransactionService.shared.insert(input)
                inserted += 1
            } catch {
                // Seguimos con las siguientes; mostramos el error al final.
                errorMessage = "Error insertando línea: \(error.localizedDescription)"
            }
        }
        insertedCount = inserted
    }
}
