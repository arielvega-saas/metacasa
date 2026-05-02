import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Observation

/// Chat multimodal del asistente financiero.
///
/// Capacidades (Sprint 4 multimodal):
/// - Texto: envía preguntas en lenguaje natural
/// - Voz: tap en mic → dictado on-device (Speech framework) → transcripción
///        aparece en el input, podés editar antes de enviar o enviar directo
/// - Imágenes: adjuntar foto de recibo → OCR on-device (Vision) →
///        ReceiptParser extrae monto/fecha/comercio/categoría →
///        ofrece crear transacción con 1 tap
/// - CSV: adjuntar archivo → TransactionCSVImporter existente procesa →
///        ofrece importar batch de transacciones
/// - .xlsx: se detecta y se pide convertir a CSV (soporte nativo requiere
///        CoreXLSX SPM, lo agregamos post-launch si es necesario)
@MainActor
struct AssistantChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AssistantViewModel.shared
    @State private var speech = SpeechRecognizerService.shared

    // Attachment pickers
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFilePicker = false
    @State private var showVoiceMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                VStack(spacing: 0) {
                    messagesScroll
                    inputBar
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .frame(width: 32, height: 32)
                            .background(Color.appSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.brandPrimary)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle().stroke(Color.brandSecondary.opacity(0.4), lineWidth: 1)
                                )
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(hex: "#0E1312"))
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text("assistant.title").font(.headline)
                            Text("assistant.subtitle")
                                .font(.caption2)
                                .foregroundStyle(Color.textMuted)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        // Pasamos la history actual al voice mode para continuidad.
                        VoiceConversationManager.shared.bridgeFrom(messages: viewModel.messages)
                        showVoiceMode = true
                    } label: {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.brandPrimary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .task { viewModel.seedWelcome() }
            .onChange(of: selectedPhoto) { _, newValue in
                Task { await handlePhotoPick(newValue) }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText, .spreadsheet, UTType(filenameExtension: "csv") ?? .plainText, UTType(filenameExtension: "xlsx") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFilePick(result: result) }
            }
            .fullScreenCover(isPresented: $showVoiceMode) {
                VoiceConversationView()
                    .environment(appState)
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.appBackground, Color.brandPrimary.opacity(0.05), Color.appBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Messages

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.messages) { msg in
                        MessageRow(message: msg, onActionTap: { action in
                            Task { await viewModel.handleAction(action, appState: appState) }
                        })
                        .id(msg.id)
                    }
                    if viewModel.isThinking {
                        thinkingBubble.id("thinking")
                    }
                    if viewModel.messages.count == 1 {
                        quickSuggestions.padding(.top, 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isThinking) { _, thinking in
                if thinking {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var thinkingBubble: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text("assistant.thinking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
    }

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("assistant.quickStart").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(suggestionsList, id: \.self) { s in
                Button {
                    viewModel.input = s
                    Task { await viewModel.send(appState: appState) }
                } label: {
                    HStack {
                        Text(s).font(.callout)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption)
                    }
                    .foregroundStyle(Color.brandPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.brandPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private let suggestionsList: [String] = [
        "¿Cómo voy este mes?",
        "¿Dónde gasto más?",
        "Hacé un presupuesto para el próximo mes",
        "¿Cuánto me va a quedar a fin de mes?",
        "¿Cómo voy con mis metas?"
    ]

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            if speech.isRecording {
                recordingBanner
            }
            HStack(alignment: .bottom, spacing: 8) {
                attachmentsMenu
                textInput
                sendOrMicButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            // En iOS 26 se observó que `.ultraThinMaterial` aplicado al input bar
            // bloquea/atrasa el hit-testing de los Buttons cuando hay animaciones
            // arriba (como el banner de grabación). Color sólido es seguro.
            .background(Color.appSurface)
        }
    }

    private var attachmentsMenu: some View {
        Menu {
            Button {
                showFilePicker = true
            } label: {
                Label {
                    Text("assistant.attachment.file")
                } icon: {
                    Image(systemName: "doc")
                }
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label {
                    Text("assistant.attachment.photo")
                } icon: {
                    Image(systemName: "photo")
                }
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 38, height: 38)
                .background(Color.appSurface)
                .clipShape(Circle())
        }
    }

    private var textInput: some View {
        TextField(speech.isRecording ? String(localized: "assistant.input.listening") : String(localized: "assistant.input.placeholder"),
                  text: $viewModel.input, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.body)
            .lineLimit(1...5)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.appSurfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .submitLabel(.send)
            .disabled(speech.isRecording)
            .onSubmit {
                Task { await viewModel.send(appState: appState) }
            }
        // NOTA: removimos el `onChange(of: speech.transcript)` que seteaba
        // `viewModel.input` en vivo — actualizar el TextField a cada partial
        // result (~5/seg) saturaba SwiftUI y bloqueaba hit-testing. Ahora la
        // transcript final se vuelca al input solo al parar (en `toggleMic`).
        // El preview live se ve dentro del banner rojo arriba.
    }

    @ViewBuilder
    private var sendOrMicButton: some View {
        if viewModel.canSend && !speech.isRecording {
            // Send
            Button {
                Task { await viewModel.send(appState: appState) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(hex: "#0E1312"))
                    .frame(width: 38, height: 38)
                    .background(Color.brandPrimary)
                    .overlay(
                        Circle().stroke(Color.brandSecondary.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        } else {
            // Mic
            Button {
                Task { await toggleMic() }
            } label: {
                Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(speech.isRecording ? .white : Color.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(speech.isRecording ? Color.brandDanger : Color.appSurfaceInset)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var recordingBanner: some View {
        HStack(spacing: 8) {
            // No usamos `symbolEffect(.pulse)` acá: aplicado a un `Circle` (Shape)
            // crashea con SIGTRAP en iOS 26. `symbolEffect` solo es válido para
            // SF Symbols (`Image(systemName:)`).
            PulsingDot()
            Text("assistant.recording")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if !speech.transcript.isEmpty {
                Text(speech.transcript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            // Botón stop explícito dentro del banner — área grande, fácil de tocar
            Button {
                print("[AssistantChat] banner stop tapped")
                Task { await toggleMic() }
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandDanger)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.brandDanger.opacity(0.12))
        .contentShape(Rectangle())
        .onTapGesture {
            print("[AssistantChat] banner area tapped")
            Task { await toggleMic() }
        }
    }

    // MARK: - Actions

    private struct PulsingDot: View {
        @State private var pulse = false
        var body: some View {
            Circle()
                .fill(Color.brandDanger)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.4 : 1.0)
                .opacity(pulse ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
        }
    }

    private func toggleMic() async {
        print("[AssistantChat] toggleMic isRecording=\(speech.isRecording)")
        Haptics.play(.impactMedium)
        if speech.isRecording {
            print("[AssistantChat] calling speech.stop()")
            speech.stop()
            print("[AssistantChat] speech.stop() returned")
            // Si hay transcripción, la pasamos al input. User puede editar o enviar.
            if !speech.transcript.isEmpty {
                viewModel.input = speech.transcript
            }
            return
        }

        // Auth first
        let auth = await SpeechRecognizerService.requestAuthorization()
        guard auth == .authorized else {
            viewModel.appendSystem(
                "Para dictar necesito permisos de micrófono y reconocimiento de voz. Activalos en Ajustes > \(String(localized: "app.name"))."
            )
            return
        }

        let localeId = AppLocaleStorage.effectiveLocale.identifier.replacingOccurrences(of: "_", with: "-")
        do {
            try await speech.start(localeIdentifier: localeId)
        } catch {
            viewModel.appendSystem("No pude iniciar el dictado: \(error.localizedDescription)")
        }
    }

    private func handlePhotoPick(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { selectedPhoto = nil }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                viewModel.appendSystem("No pude leer esa imagen.")
                return
            }
            await viewModel.handleImage(image, appState: appState)
        } catch {
            viewModel.appendSystem("Error al cargar la imagen: \(error.localizedDescription)")
        }
    }

    private func handleFilePick(result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            await viewModel.handleFile(url: url, appState: appState)
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                viewModel.appendSystem("Error al abrir el archivo: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: AssistantMessage
    let onActionTap: (AssistantAction) -> Void

    /// Renderiza el contenido con soporte para markdown (bold, italic, links).
    /// Si el parser falla (markdown malformado), cae a texto plano.
    /// Preserva los newlines reemplazándolos antes del parse — sin esto,
    /// AttributedString colapsa los `\n` en espacios (Markdown spec lo manda).
    @ViewBuilder
    private var renderedContent: some View {
        if let attributed = try? AttributedString(
            markdown: message.content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
        } else {
            Text(message.content)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if let attachment = message.attachment {
                    attachmentView(attachment)
                }
                if !message.content.isEmpty {
                    renderedContent
                        .font(.body)
                        .foregroundStyle(message.role == .user ? Color(hex: "#0E1312") : Color.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.role == .user ? Color.brandPrimary : Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(message.role == .user ? Color.clear : Color.appBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .textSelection(.enabled)
                }
                if !message.actions.isEmpty {
                    actionButtons
                }
            }

            if message.role != .user { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private func attachmentView(_ attachment: AssistantAttachment) -> some View {
        switch attachment {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: 220, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .file(_, let name):
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(Color.brandPrimary)
                Text(name)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(10)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            ForEach(message.actions, id: \.id) { action in
                Button {
                    Haptics.play(.impactMedium)
                    onActionTap(action)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: action.icon)
                        Text(action.label)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(action.destructive ? Color.brandDanger.opacity(0.15) : Color.brandPrimary.opacity(0.15))
                    .foregroundStyle(action.destructive ? Color.brandDanger : Color.brandPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Model

struct AssistantMessage: Identifiable, Sendable {
    let id = UUID()
    let role: Role
    var content: String
    var attachment: AssistantAttachment?
    var actions: [AssistantAction] = []
    let timestamp: Date = Date()

    enum Role: Sendable { case user, assistant, system }
}

enum AssistantAttachment: @unchecked Sendable {
    case image(UIImage)
    case file(URL, String) // url + display name
}

struct AssistantAction: Sendable, Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let destructive: Bool
    let kind: Kind

    enum Kind: Sendable {
        case createTransactionFromReceipt(ParsedReceipt)
        case importCSV(URL)
        case importParsed(ParsedImport)
        case discard
    }
}

@MainActor
@Observable
final class AssistantViewModel {
    /// Singleton para persistir la conversación entre aperturas del sheet.
    /// El usuario puede cerrar el chat para mirar las pantallas que sugirió
    /// el asistente y, al reabrirlo, seguir viendo el historial completo.
    static let shared = AssistantViewModel()

    var messages: [AssistantMessage] = []
    var input: String = ""
    var isThinking: Bool = false

    var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func seedWelcome() {
        guard messages.isEmpty else { return }
        messages.append(AssistantMessage(
            role: .assistant,
            content: String(localized: "assistant.welcome")
        ))
    }

    func appendSystem(_ text: String) {
        messages.append(AssistantMessage(role: .system, content: text))
    }

    // MARK: - Text send

    func send(appState: AppState) async {
        let msg = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }

        Haptics.play(.impactLight)

        // Snapshot history ANTES de agregar el nuevo user message — la API
        // espera el último mensaje aparte como `message`, no en history.
        // Solo incluimos los últimos 8 turnos (4 user + 4 assistant) para no
        // saturar el context window del LLM.
        let history: [ChatTurn] = messages
            .compactMap { m -> ChatTurn? in
                switch m.role {
                case .user: return m.content.isEmpty ? nil : .user(m.content)
                case .assistant: return m.content.isEmpty ? nil : .assistant(m.content)
                case .system: return nil
                }
            }
            .suffix(8)
            .map { $0 }

        messages.append(AssistantMessage(role: .user, content: msg))
        input = ""
        isThinking = true
        defer { isThinking = false }

        do {
            let context = try await FinancialContextBuilder.build(appState: appState)
            let response = await AIAssistantService.shared.ask(
                message: msg,
                context: context,
                householdId: appState.currentHouseholdId,
                userId: appState.currentUserId,
                history: history
            )
            messages.append(AssistantMessage(role: .assistant, content: response))
        } catch {
            messages.append(AssistantMessage(
                role: .assistant,
                content: "No pude leer tus datos ahora mismo (\(error.localizedDescription))."
            ))
        }
    }

    // MARK: - Image → OCR → Receipt

    func handleImage(_ image: UIImage, appState: AppState) async {
        Haptics.play(.impactLight)
        messages.append(AssistantMessage(role: .user, content: "", attachment: .image(image)))
        isThinking = true
        defer { isThinking = false }

        do {
            let text = try await OCRService.extractText(from: image)
            guard !text.isEmpty else {
                messages.append(AssistantMessage(
                    role: .assistant,
                    content: "No pude leer texto en esa imagen. Probá con más luz o enfocando mejor el recibo."
                ))
                return
            }

            let parsed = ReceiptParser.parse(text: text)
            let response = formatReceiptPreview(parsed)
            let actions: [AssistantAction] = parsed.amount != nil ? [
                AssistantAction(label: "Crear transacción", icon: "plus.circle.fill", destructive: false, kind: .createTransactionFromReceipt(parsed)),
                AssistantAction(label: "Descartar", icon: "trash", destructive: true, kind: .discard)
            ] : []

            messages.append(AssistantMessage(
                role: .assistant,
                content: response,
                attachment: nil,
                actions: actions
            ))
        } catch {
            messages.append(AssistantMessage(
                role: .assistant,
                content: "No pude procesar la imagen: \(error.localizedDescription)"
            ))
        }
    }

    private func formatReceiptPreview(_ parsed: ParsedReceipt) -> String {
        var lines = ["📸 Leí este recibo:\n"]
        if let amount = parsed.amount {
            let curr = parsed.currency ?? "USD"
            lines.append("• Monto: \(Money.format(amount, currency: curr))")
        } else {
            lines.append("• Monto: no pude detectarlo")
        }
        if let date = parsed.date {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.locale = AppLocaleStorage.effectiveLocale
            lines.append("• Fecha: \(df.string(from: date))")
        }
        if let merchant = parsed.merchant {
            lines.append("• Comercio: \(merchant)")
        }
        if let category = parsed.category {
            lines.append("• Categoría sugerida: \(category)")
        }
        if parsed.amount != nil {
            lines.append("")
            lines.append("¿Creo la transacción?")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - File → CSV / XLSX parsing inline

    func handleFile(url: URL, appState: AppState) async {
        Haptics.play(.impactLight)
        let name = url.lastPathComponent
        messages.append(AssistantMessage(role: .user, content: "", attachment: .file(url, name)))
        isThinking = true
        defer { isThinking = false }

        let ext = url.pathExtension.lowercased()

        // 1. XLSX/XLS → parseamos con CoreXLSX, convertimos a CSV, seguimos flujo normal.
        if ext == "xlsx" || ext == "xls" {
            do {
                let rows = try XLSXImportService.readRows(from: url)
                let csv = XLSXImportService.toCSV(rows: rows)
                await presentCSVPreview(fileName: name, csv: csv, rowCount: rows.count, appState: appState)
            } catch {
                messages.append(AssistantMessage(
                    role: .assistant,
                    content: "❌ No pude leer ese Excel: \(error.localizedDescription). Probá con otro archivo o convertilo a CSV."
                ))
            }
            return
        }

        // 2. CSV/TSV → leemos como texto + preview.
        if ext == "csv" || ext == "tsv" || ext == "txt" {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                messages.append(AssistantMessage(role: .assistant, content: "No pude leer el archivo como texto UTF-8."))
                return
            }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            await presentCSVPreview(fileName: name, csv: text, rowCount: lines.count, appState: appState)
            return
        }

        messages.append(AssistantMessage(
            role: .assistant,
            content: "No reconozco ese tipo de archivo. Soporto CSV, TSV, XLS, XLSX."
        ))
    }

    /// Parsea el CSV con `TransactionCSVImporter`, resume en el chat y ofrece
    /// importar inline (sin redirigir al tab Transacciones).
    private func presentCSVPreview(fileName: String, csv: String, rowCount: Int, appState: AppState) async {
        guard let hid = appState.currentHouseholdId else {
            messages.append(AssistantMessage(role: .assistant, content: "No hay hogar activo."))
            return
        }

        // Traemos existentes para dedupe (último año)
        let now = Date()
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -365, to: now) ?? now
        let existing = (try? await TransactionService.shared.fetchForPeriod(
            householdId: hid, from: start, to: now, limit: 5000
        )) ?? []

        let parsed = TransactionCSVImporter.parse(text: csv, existing: existing)
        let summary = """
        📄 **\(fileName)** — \(rowCount) filas.

        Detecté:
        • ✅ \(parsed.validCount) transacciones válidas
        • 📋 \(parsed.duplicateCount) duplicadas (se saltean)
        • ⚠️ \(parsed.errorCount) con errores

        ¿Querés importarlas ahora?
        """
        var actions: [AssistantAction] = [
            AssistantAction(label: "Descartar", icon: "trash", destructive: true, kind: .discard)
        ]
        if parsed.validCount > 0 {
            actions.insert(
                AssistantAction(label: "Importar \(parsed.validCount)", icon: "arrow.down.doc.fill", destructive: false, kind: .importParsed(parsed)),
                at: 0
            )
        }
        messages.append(AssistantMessage(role: .assistant, content: summary, actions: actions))
    }

    // MARK: - Action handlers

    func handleAction(_ action: AssistantAction, appState: AppState) async {
        switch action.kind {
        case .createTransactionFromReceipt(let receipt):
            await createTransaction(from: receipt, appState: appState)
        case .importCSV(let url):
            appendSystem("Abrí el tab Transacciones > botón Importar para procesar el archivo con preview y mapping completo.")
            _ = url
        case .importParsed(let parsed):
            await commitImport(parsed: parsed, appState: appState)
        case .discard:
            appendSystem("Descartado. 👍")
        }
    }

    @MainActor
    private func commitImport(parsed: ParsedImport, appState: AppState) async {
        guard let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else {
            appendSystem("Falta sesión o hogar activo.")
            return
        }
        let defaultCurrency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"
        let inputs = TransactionCSVImporter.buildInputs(
            from: parsed,
            householdId: hid,
            userId: uid,
            defaultCurrency: defaultCurrency
        )

        isThinking = true
        defer { isThinking = false }

        var inserted = 0
        var failed = 0
        for input in inputs {
            do {
                _ = try await TransactionService.shared.insert(input)
                inserted += 1
            } catch {
                failed += 1
            }
        }

        Haptics.play(.success)
        let msg = failed == 0
            ? "✅ \(inserted) transacciones importadas con éxito."
            : "⚠️ \(inserted) importadas, \(failed) fallaron."
        messages.append(AssistantMessage(role: .assistant, content: msg))
    }

    private func createTransaction(from receipt: ParsedReceipt, appState: AppState) async {
        guard let amount = receipt.amount else {
            appendSystem("No hay monto detectado. No puedo crear la tx.")
            return
        }
        guard let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else {
            appendSystem("Falta hogar o sesión activa.")
            return
        }
        let currency = receipt.currency
            ?? appState.households.first(where: { $0.id == hid })?.defaultCurrency
            ?? "USD"

        let input = NewTransactionInput(
            householdId: hid,
            userId: uid,
            accountId: nil,
            type: .gasto,
            amount: amount,
            currencyOriginal: currency,
            category: receipt.category ?? "Otro",
            subcategory: nil,
            note: receipt.merchant.map { "Recibo: \($0)" },
            date: receipt.date ?? Date()
        )

        do {
            _ = try await TransactionService.shared.insert(input)
            Haptics.play(.success)
            messages.append(AssistantMessage(
                role: .assistant,
                content: "✅ Transacción creada: gasto de \(Money.format(amount, currency: currency, style: .compact)) en \(receipt.category ?? "Otro")."
            ))
        } catch {
            Haptics.play(.error)
            messages.append(AssistantMessage(
                role: .assistant,
                content: "No pude crear la transacción: \(error.localizedDescription)"
            ))
        }
    }
}
