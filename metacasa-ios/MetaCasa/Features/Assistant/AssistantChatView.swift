import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Observation
import VisionKit

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
    @Environment(PrivacyManager.self) private var privacy
    @State private var viewModel = AssistantViewModel.shared
    @State private var speech = SpeechRecognizerService.shared
    @State private var showConsentSheet = false

    // Attachment pickers
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showFilePicker = false
    @State private var showPhotoPicker = false
    @State private var showVoiceMode = false
    @State private var showScanner = false

    // UX polish (Sprint 2026-05-06)
    @State private var showPrivacyExplainer = false
    @FocusState private var inputFocused: Bool
    @State private var thinkingPulse: [Bool] = [false, false, false]

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
                        VStack(alignment: .leading, spacing: 2) {
                            Text("assistant.title").font(.headline)
                            privacyBadge
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
            .task {
                await viewModel.bootstrap(appState: appState)
                // Apple Review 5.1.1 + GDPR/CCPA: pedir consent explícito
                // antes de cualquier request a Claude. Si el user ya aceptó,
                // este sheet no aparece. La decisión persiste en UserDefaults.
                if !privacy.assistantCloudConsent {
                    showConsentSheet = true
                }
            }
            .onDisappear { viewModel.closeSession(appState: appState) }
            .sheet(isPresented: $showConsentSheet) {
                AssistantConsentSheet(privacy: privacy)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .onChange(of: selectedPhotos) { _, newValue in
                guard !newValue.isEmpty else { return }
                Task { await handlePhotosPick(newValue) }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            )
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
            .sheet(isPresented: $showScanner) {
                DocumentScannerView { images in
                    showScanner = false
                    guard !images.isEmpty else { return }
                    Task { await viewModel.handleImages(images, appState: appState) }
                } onCancel: {
                    showScanner = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPrivacyExplainer) {
                PrivacyExplainerSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Privacy badge

    private var privacyBadge: some View {
        Button {
            Haptics.play(.selection)
            showPrivacyExplainer = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("On-device · Privado")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.brandPrimary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.brandPrimary.opacity(0.12)))
            .overlay(Capsule().stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
            HStack(alignment: .center, spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.brandPrimary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(thinkingPulse[i] ? 1.0 : 0.55)
                        .opacity(thinkingPulse[i] ? 1.0 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: thinkingPulse[i]
                        )
                }
                Text("assistant.thinking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear {
                for i in 0..<3 { thinkingPulse[i] = true }
            }
            Spacer()
        }
    }

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("assistant.quickStart")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            ForEach(suggestionsList, id: \.raw) { s in
                Button {
                    Haptics.play(.selection)
                    viewModel.input = s.raw
                    Task { await viewModel.send(appState: appState) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: s.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.brandPrimary.opacity(0.12)))
                        Text(s.raw)
                            .font(.callout)
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.textDim)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .pressableScale(0.97)
            }
        }
    }

    private struct QuickSuggestion: Hashable {
        let icon: String
        let raw: String
    }

    private let suggestionsList: [QuickSuggestion] = [
        .init(icon: "chart.bar.fill",         raw: "¿Cómo voy este mes?"),
        .init(icon: "mappin.and.ellipse",     raw: "¿Dónde gasto más?"),
        .init(icon: "calendar",               raw: "Hacé un presupuesto para el próximo mes"),
        .init(icon: "chart.pie.fill",         raw: "¿Cuánto me va a quedar a fin de mes?"),
        .init(icon: "flag.fill",              raw: "¿Cómo voy con mis metas?")
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
            if VNDocumentCameraViewController.isSupported {
                Button {
                    showScanner = true
                } label: {
                    Label {
                        Text("Escanear recibo")
                    } icon: {
                        Image(systemName: "doc.viewfinder")
                    }
                }
            }
            Button {
                showFilePicker = true
            } label: {
                Label {
                    Text("assistant.attachment.file")
                } icon: {
                    Image(systemName: "doc")
                }
            }
            Button {
                showPhotoPicker = true
            } label: {
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
            .focused($inputFocused)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(minHeight: 48)
            .background(Color.appSurfaceInset)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(inputFocused ? Color.brandPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
                    .animation(.easeOut(duration: 0.2), value: inputFocused)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .glowIfPositive(inputFocused, radius: 22)
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
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hex: "#0E1312"))
                    .frame(width: 48, height: 48)
                    .background(Color.brandPrimary)
                    .overlay(
                        Circle().stroke(Color.brandSecondary.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .pressableScale(0.94, haptic: .impactLight)
        } else {
            // Mic
            Button {
                Task { await toggleMic() }
            } label: {
                Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(speech.isRecording ? .white : Color.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(speech.isRecording ? Color.brandDanger : Color.appSurfaceInset)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .pressableScale(0.94, haptic: .impactLight)
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

    private func handlePhotosPick(_ items: [PhotosPickerItem]) async {
        defer { selectedPhotos = [] }

        var images: [UIImage] = []
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }
                images.append(image)
            } catch {
                NSLog("[Photo] failed to load item: \(error.localizedDescription)")
            }
        }
        guard !images.isEmpty else {
            viewModel.appendSystem("No pude leer las imágenes seleccionadas.")
            return
        }
        await viewModel.handleImages(images, appState: appState)
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

// MARK: - Privacy explainer

private struct PrivacyExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.brandPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tu privacidad, primero")
                        .font(.mcSerifTitle)
                        .foregroundStyle(Color.textPrimary)
                    Text("Qué procesamos en tu dispositivo y qué no")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textMuted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {
                privacyRow(
                    icon: "iphone",
                    title: "En tu iPhone",
                    body: "Reconocimiento de voz, OCR de recibos y comandos rápidos corren on-device con Apple Speech y Vision. Nada sale del teléfono."
                )
                privacyRow(
                    icon: "cloud",
                    title: "En la nube (solo cuando hace falta)",
                    body: "Si tu pregunta requiere razonamiento complejo o entender una imagen, la enviamos a Claude (Anthropic). Nunca compartimos saldos, ni números de tarjeta, ni emails."
                )
                privacyRow(
                    icon: "hand.raised.fill",
                    title: "Vos mandás",
                    body: "Podés activar el modo solo on-device en Ajustes — más lento para preguntas largas, pero garantizado offline."
                )
            }

            Spacer()

            Button { dismiss() } label: {
                Text("Entendido")
            }
            .buttonStyle(MCPrimaryButton())
        }
        .padding(24)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func privacyRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.brandPrimary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.mcBody.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text(body)
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Message Row

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct MessageRow: View {
    let message: AssistantMessage
    let onActionTap: (AssistantAction) -> Void
    @State private var imageViewerImage: IdentifiableImage?

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
        .fullScreenCover(item: $imageViewerImage) { wrapper in
            ImageViewer(image: wrapper.image)
        }
    }

    @ViewBuilder
    private func attachmentView(_ attachment: AssistantAttachment) -> some View {
        switch attachment {
        case .image(let image):
            Button {
                imageViewerImage = IdentifiableImage(image: image)
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 220, maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
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
        case createMultipleTransactions([ParsedReceipt])
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

    /// Resúmenes de conversaciones anteriores cargados desde disco. Se inyectan
    /// al system prompt del LLM como `=== PREVIOUS CONVERSATIONS ===` para
    /// memoria conversacional persistente entre sesiones.
    private var pastSummaries: [String] = []

    /// Tracking de la sesión persistida. Si el hogar cambia, re-bootstrap.
    private var loadedHouseholdId: UUID?

    var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Lifecycle

    /// Bootstrap del chat al abrir el sheet. Carga la sesión persistida del
    /// hogar activo (si existe), hidrata el array `messages` con los mensajes
    /// históricos, y carga los últimos 3 resúmenes para inyectar al prompt.
    /// Si el hogar cambió desde el último bootstrap, re-hidrata (multi-hogar
    /// safety — sin leak cruzado).
    func bootstrap(appState: AppState) async {
        guard let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else {
            seedWelcomeIfEmpty()
            return
        }

        if loadedHouseholdId == hid && !messages.isEmpty {
            // Mismo hogar y ya hay contenido — no recargar, mantener estado UI.
            return
        }

        let session = await ChatPersistenceService.shared
            .loadCurrent(householdId: hid, userId: uid)

        // Hidratar messages con el contenido persistido. Solo user/assistant
        // (system messages son efímeros y no se persisten).
        messages = session.messages.map { rec in
            AssistantMessage(
                role: {
                    switch rec.role {
                    case .user: return .user
                    case .assistant: return .assistant
                    case .system: return .system
                    }
                }(),
                content: rec.content
            )
        }
        loadedHouseholdId = hid
        seedWelcomeIfEmpty()

        // Cargar resúmenes en background — no bloquea la UI.
        pastSummaries = await ChatPersistenceService.shared
            .recentSummaries(householdId: hid, limit: 3)
    }

    /// Cierra la sesión actual al dismissar el chat. Si tuvo >4 mensajes,
    /// dispara el resumen via Claude Haiku en background. Fire-and-forget.
    func closeSession(appState: AppState) {
        guard let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else { return }
        Task.detached {
            let token = await TokenHolder.shared.get()
            await ChatPersistenceService.shared.closeAndSummarize(
                householdId: hid,
                userId: uid,
                accessToken: token
            )
        }
    }

    private func seedWelcomeIfEmpty() {
        guard messages.isEmpty else { return }
        messages.append(AssistantMessage(
            role: .assistant,
            content: String(localized: "assistant.welcome")
        ))
    }

    /// Public alias mantenido para compatibilidad con el `.task` existente.
    /// Llamadores nuevos deberían usar `bootstrap(appState:)`.
    func seedWelcome() {
        seedWelcomeIfEmpty()
    }

    func appendSystem(_ text: String) {
        messages.append(AssistantMessage(role: .system, content: text))
    }

    // MARK: - Persistence helper

    /// Persiste un mensaje user/assistant en la sesión actual (no system).
    private func persist(_ msg: AssistantMessage, appState: AppState, hadAttachment: Bool = false) {
        guard let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId,
              msg.role != .system else { return }
        let role: ChatMessageRecord.Role = msg.role == .user ? .user : .assistant
        let record = ChatMessageRecord(
            id: msg.id,
            role: role,
            content: msg.content,
            timestamp: msg.timestamp,
            hadAttachment: hadAttachment
        )
        Task.detached {
            await ChatPersistenceService.shared.appendMessage(
                record,
                householdId: hid,
                userId: uid
            )
        }
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

        let userMsg = AssistantMessage(role: .user, content: msg)
        messages.append(userMsg)
        persist(userMsg, appState: appState)
        input = ""
        isThinking = true
        defer { isThinking = false }

        do {
            // Refresh proactivo del JWT — sin esto el asistente cae con 401
            // después de 1h. supabase-swift auto-refresha con refresh_token.
            await AuthManager.shared.ensureFreshToken()
            let context = try await FinancialContextBuilder.build(appState: appState)
            let allowCloud = PrivacyManager.shared.canUseCloudAssistant
            let response = await AIAssistantService.shared.ask(
                message: msg,
                context: context,
                householdId: appState.currentHouseholdId,
                userId: appState.currentUserId,
                history: history,
                pastSummaries: pastSummaries,
                allowCloud: allowCloud
            )
            let reply = AssistantMessage(role: .assistant, content: response)
            messages.append(reply)
            persist(reply, appState: appState)
        } catch {
            let errMsg = AssistantMessage(
                role: .assistant,
                content: "No pude leer tus datos ahora mismo (\(error.localizedDescription))."
            )
            messages.append(errMsg)
            persist(errMsg, appState: appState)
        }
    }

    // MARK: - Image → OCR → Receipt

    func handleImages(_ images: [UIImage], appState: AppState) async {
        guard !images.isEmpty else { return }
        Haptics.play(.impactLight)
        for img in images {
            let userMsg = AssistantMessage(role: .user, content: "", attachment: .image(img))
            messages.append(userMsg)
            // Persistimos un placeholder para que en el resumen futuro el LLM
            // sepa que en ese turno hubo una imagen (no persistimos la image
            // raw — pesada y ya consumida).
            persist(userMsg, appState: appState, hadAttachment: true)
        }
        isThinking = true
        defer { isThinking = false }

        // Refresh proactivo del JWT — sin esto vision falla con 401 si pasó
        // > 1h desde que el user abrió la app.
        await AuthManager.shared.ensureFreshToken()

        // Tier preferido: mandar las imágenes DIRECTO a Claude vision en una
        // sola request multimodal. Mucho más eficiente que llamadas separadas
        // y le da contexto cruzado al modelo. Si falla, fallback OCR.
        if let token = await TokenHolder.shared.get() {
            let jpegDatas = images.compactMap { Self.compressedJPEGData(from: $0) }
            if !jpegDatas.isEmpty {
                do {
                    let receipts = try await AnthropicProvider.shared
                        .parseImageReceipts(jpegDatas: jpegDatas, accessToken: token)
                    appendImageResultMessage(receipts: receipts, appState: appState)
                    return
                } catch {
                    NSLog("[Receipt] Claude vision failed (\(error.localizedDescription)), falling back to OCR")
                }
            }
        }

        // Fallback: OCR sobre cada imagen + parser regex (solo recibos únicos).
        var allReceipts: [ParsedReceipt] = []
        for image in images {
            do {
                let text = try await OCRService.extractText(from: image)
                guard !text.isEmpty else { continue }
                let parsed = ReceiptParser.parse(text: text)
                if parsed.amount != nil { allReceipts.append(parsed) }
            } catch {
                NSLog("[OCR] failed: \(error.localizedDescription)")
            }
        }
        appendImageResultMessage(receipts: allReceipts, appState: appState)
    }

    private func appendImageResultMessage(receipts: [ParsedReceipt], appState: AppState) {
        if receipts.isEmpty {
            let m = AssistantMessage(
                role: .assistant,
                content: "No detecté gastos identificables en esa imagen. Probá con un recibo más claro o un screenshot que muestre montos y comercios."
            )
            messages.append(m)
            persist(m, appState: appState)
            return
        }
        if receipts.count == 1 {
            let receipt = receipts[0]
            let response = formatReceiptPreview(receipt)
            let actions: [AssistantAction] = receipt.amount != nil ? [
                AssistantAction(label: "Crear transacción", icon: "plus.circle.fill", destructive: false, kind: .createTransactionFromReceipt(receipt)),
                AssistantAction(label: "Descartar", icon: "trash", destructive: true, kind: .discard)
            ] : []
            let m = AssistantMessage(role: .assistant, content: response, attachment: nil, actions: actions)
            messages.append(m)
            persist(m, appState: appState)
            return
        }
        // Listado: mostrar resumen con N items + 1 acción bulk.
        let preview = formatReceiptsListPreview(receipts)
        let actions: [AssistantAction] = [
            AssistantAction(label: "Crear las \(receipts.count)", icon: "plus.rectangle.on.rectangle", destructive: false, kind: .createMultipleTransactions(receipts)),
            AssistantAction(label: "Descartar", icon: "trash", destructive: true, kind: .discard)
        ]
        let m = AssistantMessage(role: .assistant, content: preview, attachment: nil, actions: actions)
        messages.append(m)
        persist(m, appState: appState)
    }

    private func formatReceiptsListPreview(_ receipts: [ParsedReceipt]) -> String {
        var lines = ["📋 Detecté \(receipts.count) gastos:\n"]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.locale = AppLocaleStorage.effectiveLocale
        for r in receipts.prefix(15) {
            let amount = r.amount.map { Money.format($0, currency: r.currency ?? "USD", style: .compact) } ?? "?"
            let merchant = r.merchant ?? "—"
            let date = r.date.map { dateFormatter.string(from: $0) } ?? ""
            let cat = r.category.map { " · \($0)" } ?? ""
            lines.append("• \(amount) · \(merchant)\(cat) \(date)")
        }
        if receipts.count > 15 {
            lines.append("• … y \(receipts.count - 15) más")
        }
        return lines.joined(separator: "\n")
    }

    private static func compressedJPEGData(from image: UIImage, maxDimension: CGFloat = 1568, quality: CGFloat = 0.8) -> Data? {
        let longSide = max(image.size.width, image.size.height)
        if longSide <= maxDimension {
            return image.jpegData(compressionQuality: quality)
        }
        let scale = maxDimension / longSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
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
        let m = AssistantMessage(role: .assistant, content: summary, actions: actions)
        messages.append(m)
        persist(m, appState: appState)
    }

    // MARK: - Action handlers

    func handleAction(_ action: AssistantAction, appState: AppState) async {
        switch action.kind {
        case .createTransactionFromReceipt(let receipt):
            await createTransaction(from: receipt, appState: appState)
        case .createMultipleTransactions(let receipts):
            await createMultipleTransactions(from: receipts, appState: appState)
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
        let m = AssistantMessage(role: .assistant, content: msg)
        messages.append(m)
        persist(m, appState: appState)
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
            let m = AssistantMessage(
                role: .assistant,
                content: "✅ Transacción creada: gasto de \(Money.format(amount, currency: currency, style: .compact)) en \(receipt.category ?? "Otro")."
            )
            messages.append(m)
            persist(m, appState: appState)
        } catch {
            Haptics.play(.error)
            let m = AssistantMessage(
                role: .assistant,
                content: "No pude crear la transacción: \(error.localizedDescription)"
            )
            messages.append(m)
            persist(m, appState: appState)
        }
    }

    private func createMultipleTransactions(from receipts: [ParsedReceipt], appState: AppState) async {
        guard let hid = appState.currentHouseholdId,
              let uid = appState.currentUserId else {
            appendSystem("Falta hogar o sesión activa.")
            return
        }
        let defaultCurrency = appState.households.first(where: { $0.id == hid })?.defaultCurrency ?? "USD"

        isThinking = true
        defer { isThinking = false }

        var inserted = 0
        var failed = 0
        for receipt in receipts {
            guard let amount = receipt.amount else { failed += 1; continue }
            let input = NewTransactionInput(
                householdId: hid,
                userId: uid,
                accountId: nil,
                type: .gasto,
                amount: amount,
                currencyOriginal: receipt.currency ?? defaultCurrency,
                category: receipt.category ?? "Otro",
                subcategory: nil,
                note: receipt.merchant.map { "De foto: \($0)" },
                date: receipt.date ?? Date()
            )
            do {
                _ = try await TransactionService.shared.insert(input)
                inserted += 1
            } catch {
                failed += 1
            }
        }

        Haptics.play(.success)
        let summary = failed == 0
            ? "✅ \(inserted) transacciones creadas con éxito."
            : "⚠️ \(inserted) creadas, \(failed) fallaron."
        let m = AssistantMessage(role: .assistant, content: summary)
        messages.append(m)
        persist(m, appState: appState)
    }
}

// MARK: - Document Scanner (VisionKit)

/// Wrapper SwiftUI de `VNDocumentCameraViewController`. Ofrece auto-crop,
/// corrección de perspectiva y enhance — la misma cámara que usa Notes para
/// escanear documentos. El usuario puede capturar varias páginas en un solo
/// session; cada página vuelve como UIImage limpia.
private struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var pages: [UIImage] = []
            for i in 0..<scan.pageCount {
                pages.append(scan.imageOfPage(at: i))
            }
            onComplete(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) {
            NSLog("[Scanner] failed: \(error.localizedDescription)")
            onCancel()
        }
    }
}

// MARK: - Image Viewer (fullscreen con zoom)

private struct ImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = max(1, min(lastScale * value.magnification, 6))
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale <= 1.05 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1 else { return }
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if scale > 1 {
                            scale = 1; lastScale = 1
                            offset = .zero; lastOffset = .zero
                        } else {
                            scale = 2.5; lastScale = 2.5
                        }
                    }
                }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .padding()
            }
        }
        .statusBarHidden()
    }
}
