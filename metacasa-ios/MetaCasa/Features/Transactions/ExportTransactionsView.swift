import SwiftUI

/// Modal para configurar y ejecutar un export de movimientos.
///
/// Flujo:
///   1. Usuario elige formato (CSV / PDF) y rango de fechas.
///   2. Tap "Generar" → traemos las transacciones filtradas de Supabase,
///      construimos el archivo en temp, y ofrecemos `ShareLink`.
///   3. Share Sheet nativo permite AirDrop / Mail / Drive / WhatsApp / Files.
@MainActor
struct ExportTransactionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    @State private var format: ExportFormat = .csv
    @State private var range: ExportDateRange = .currentMonth
    @State private var customFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customTo: Date = Date()

    @State private var isBuilding = false
    @State private var errorMessage: String?
    @State private var doc: ExportedDocument?

    var body: some View {
        NavigationStack {
            Form {
                formatSection
                rangeSection
                if case .custom = range {
                    customDatesSection
                }
                if let doc {
                    Section {
                        readyState(doc)
                    }
                } else {
                    Section {
                        generateButton
                    }
                }
                if let msg = errorMessage {
                    Section {
                        Text(msg).foregroundStyle(Color.brandDanger)
                    }
                }
            }
            .navigationTitle(Text("export.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var formatSection: some View {
        Section("export.format") {
            Picker("export.format", selection: $format) {
                Text("CSV").tag(ExportFormat.csv)
                Text("PDF").tag(ExportFormat.pdf)
            }
            .pickerStyle(.segmented)

            Text(format == .csv ? "export.hint.csv" : "export.hint.pdf")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rangeSection: some View {
        Section("export.range") {
            Picker("export.range", selection: $range) {
                Text("export.range.currentMonth").tag(ExportDateRange.currentMonth)
                Text("export.range.lastMonth").tag(ExportDateRange.lastMonth)
                Text("export.range.last30").tag(ExportDateRange.last30Days)
                Text("export.range.last90").tag(ExportDateRange.last90Days)
                Text("export.range.ytd").tag(ExportDateRange.ytd)
                Text("export.range.allTime").tag(ExportDateRange.allTime)
                Text("export.range.custom").tag(ExportDateRange.custom(from: customFrom, to: customTo))
            }
        }
    }

    private var customDatesSection: some View {
        Section("export.custom") {
            DatePicker("export.from", selection: $customFrom, displayedComponents: .date)
            DatePicker("export.to", selection: $customTo, displayedComponents: .date)
        }
    }

    private var generateButton: some View {
        Button {
            Task { await build() }
        } label: {
            HStack {
                if isBuilding {
                    ProgressView().tint(.primary)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text("export.generate")
            }
        }
        .disabled(isBuilding)
    }

    @ViewBuilder
    private func readyState(_ doc: ExportedDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(doc.fileName)
                    .font(.system(.caption, design: .monospaced))
            } icon: {
                Image(systemName: doc.format == .pdf ? "doc.richtext" : "tablecells")
                    .foregroundStyle(.tint)
            }
            HStack(spacing: 4) {
                Text("export.ready")
                Text("·").foregroundStyle(.tertiary)
                Text(doc.byteCount.formatted(.byteCount(style: .file)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        ShareLink(item: doc.url, preview: SharePreview(doc.fileName)) {
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                Text("action.share")
            }
        }

        Button(role: .destructive) {
            self.doc = nil
        } label: {
            Text("export.reset")
        }
    }

    // MARK: - Actions

    @MainActor
    private func build() async {
        errorMessage = nil
        guard let hid = appState.currentHouseholdId else {
            errorMessage = String(localized: "error.household_missing")
            return
        }
        let household = appState.households.first(where: { $0.id == hid })
        let householdName = household?.name ?? "Household"
        let householdCurrency = household?.defaultCurrency ?? "USD"

        // Actualizar el .custom con las fechas actuales (el picker puede haber
        // cambiado customFrom/customTo desde el .tag original).
        let effectiveRange: ExportDateRange = {
            if case .custom = range {
                return .custom(from: customFrom, to: customTo)
            }
            return range
        }()

        let dates = effectiveRange.resolved()

        isBuilding = true
        defer { isBuilding = false }

        do {
            let txs = try await TransactionService.shared.fetchForPeriod(
                householdId: hid,
                from: dates.from,
                to: dates.to,
                limit: 10_000
            )

            let newDoc: ExportedDocument
            switch format {
            case .csv:
                newDoc = try TransactionCSVExporter.export(
                    transactions: txs,
                    householdName: householdName,
                    householdCurrency: householdCurrency,
                    dateRange: dates,
                    locale: locale
                )
            case .pdf:
                newDoc = try TransactionPDFExporter.export(
                    transactions: txs,
                    householdName: householdName,
                    householdCurrency: householdCurrency,
                    dateRange: dates,
                    locale: locale
                )
            }
            doc = newDoc
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
