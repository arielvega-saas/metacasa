import SwiftUI
import UniformTypeIdentifiers

/// UI para exportar/restaurar backup JSON del hogar.
/// Export: genera el archivo y ofrece `ShareLink` nativo (AirDrop, Mail, Files,
/// WhatsApp, iCloud Drive, etc.).
/// Import: `.fileImporter` → confirmar → restore → reporte.
@MainActor
struct BackupView: View {
    @Environment(AppState.self) private var appState

    @State private var isBuilding = false
    @State private var builtFile: URL?
    @State private var errorMessage: String?

    @State private var showImportPicker = false
    @State private var isRestoring = false
    @State private var restoreReport: BackupService.RestoreReport?
    @State private var showRestoreConfirm = false
    @State private var pendingPayload: BackupService.Payload?

    var body: some View {
        Form {
            exportSection
            importSection

            if let report = restoreReport {
                Section {
                    reportRow(icon: "list.bullet", labelKey: "backup.report.txAdded", value: report.transactions)
                    if report.transactionsDuplicated > 0 {
                        reportRow(icon: "doc.on.doc", labelKey: "backup.report.duplicates", value: report.transactionsDuplicated)
                    }
                    reportRow(icon: "banknote", labelKey: "backup.report.accounts", value: report.accounts)
                    reportRow(icon: "repeat", labelKey: "backup.report.recurring", value: report.recurring)
                    reportRow(icon: "target", labelKey: "backup.report.goals", value: report.goals)
                    if report.categoriesRestored {
                        Label {
                            Text("backup.report.categoriesRestored")
                        } icon: {
                            Image(systemName: "tag")
                        }
                        .foregroundStyle(Color.brandSuccess)
                    }
                    if !report.skipped.isEmpty {
                        Text("backup.report.skipped \(report.skipped.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("backup.section.report")
                }
            }

            if let msg = errorMessage {
                Section {
                    Label {
                        Text(msg)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(Color.brandDanger)
                    .font(.caption)
                }
            }
        }
        .navigationTitle(Text("backup.title"))
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportFile(result: result)
        }
        .confirmationDialog(
            "backup.import.confirm",
            isPresented: $showRestoreConfirm,
            titleVisibility: .visible
        ) {
            Button("backup.section.restore", role: .destructive) {
                Task { await performRestore() }
            }
            Button("action.cancel", role: .cancel) {
                pendingPayload = nil
            }
        }
    }

    // MARK: - Sections

    private var exportSection: some View {
        Section {
            Text("backup.export.description")
                .font(.caption).foregroundStyle(.secondary)

            if let url = builtFile {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text(url.lastPathComponent)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: "doc.badge.arrow.up")
                            .foregroundStyle(Color.brandPrimary)
                    }
                    ShareLink(item: url, preview: SharePreview(url.lastPathComponent)) {
                        Label {
                            Text("backup.export.share")
                        } icon: {
                            Image(systemName: "square.and.arrow.up.fill")
                        }
                    }
                    Button(role: .destructive) {
                        builtFile = nil
                    } label: {
                        Text("backup.export.discard")
                    }
                    .font(.caption)
                }
            } else {
                Button {
                    Task { await buildExport() }
                } label: {
                    HStack {
                        if isBuilding {
                            ProgressView().tint(.primary)
                        } else {
                            Image(systemName: "arrow.down.doc")
                        }
                        Text("backup.export.generate")
                    }
                }
                .disabled(isBuilding)
            }
        } header: {
            Text("backup.section.export")
        }
    }

    private var importSection: some View {
        Section {
            Text("backup.import.description")
                .font(.caption).foregroundStyle(.secondary)

            Button {
                showImportPicker = true
                errorMessage = nil
                restoreReport = nil
            } label: {
                HStack {
                    if isRestoring {
                        ProgressView().tint(.primary)
                    } else {
                        Image(systemName: "arrow.up.doc")
                    }
                    Text("backup.import.pick")
                }
            }
            .disabled(isRestoring)
        } header: {
            Text("backup.section.restore")
        }
    }

    private func reportRow(icon: String, labelKey: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Label {
                Text(labelKey)
            } icon: {
                Image(systemName: icon)
            }
            Spacer()
            Text("\(value)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(value > 0 ? Color.brandSuccess : Color.textMuted)
        }
    }

    // MARK: - Actions

    @MainActor
    private func buildExport() async {
        guard let hid = appState.currentHouseholdId else {
            errorMessage = String(localized: "backup.errors.noHousehold")
            return
        }
        errorMessage = nil
        isBuilding = true
        defer { isBuilding = false }
        do {
            let payload = try await BackupService.shared.build(householdId: hid)
            let url = try await BackupService.shared.writeJSONFile(payload)
            builtFile = url
            Haptics.play(.success)
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }

    private func handleImportFile(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { @MainActor in
                do {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let payload = try await BackupService.shared.readJSONFile(url)
                    pendingPayload = payload
                    showRestoreConfirm = true
                } catch {
                    errorMessage = "\(String(localized: "backup.errors.readFail")): \(error.localizedDescription)"
                }
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func performRestore() async {
        guard let payload = pendingPayload,
              let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else {
            errorMessage = String(localized: "backup.errors.noSession")
            return
        }
        errorMessage = nil
        isRestoring = true
        defer { isRestoring = false }
        do {
            let report = try await BackupService.shared.restore(
                payload: payload,
                targetHouseholdId: hid,
                userId: uid
            )
            restoreReport = report
            pendingPayload = nil
            Haptics.play(.success)
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }
}
