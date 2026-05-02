import Foundation
import Observation

/// Coordina la conversación por voz: STT → LLM → TTS → STT (loop).
///
/// Usa los servicios existentes:
/// - `SpeechRecognizerService.shared` para STT
/// - `AIAssistantService.shared` para procesar el texto
/// - `TTSService.shared` para hablar la respuesta
///
/// Mantiene una conversación independiente del chat de texto. Si querés que
/// compartan history, podés llamar a `bridgeFrom(messages:)` antes de empezar.
@MainActor
@Observable
final class VoiceConversationManager {
    static let shared = VoiceConversationManager()
    private init() {}

    enum State: Equatable, Sendable {
        case idle
        case listening
        case thinking
        case speaking
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var lastUserUtterance: String = ""
    private(set) var lastAssistantResponse: String = ""
    /// Audio level del usuario hablando (0–1). El UI lo usa para animar el orb.
    private(set) var userAudioLevel: Float = 0
    var isMuted: Bool = false

    private var conversationHistory: [ChatTurn] = []
    private let speech = SpeechRecognizerService.shared
    private let tts = TTSService.shared
    private let cloudTTS = CloudTTSService.shared
    private var sessionStarted = false

    /// Si está en true (default), usa OpenAI TTS para voces premium tipo ChatGPT.
    /// Si false, fallback al AVSpeechSynthesizer local (más robótico pero free).
    var useCloudTTS: Bool = true

    /// Auto-VAD: si el transcript no cambia por X segundos, asumimos que el user
    /// terminó de hablar y procesamos automáticamente. Mucho más fluido que
    /// "tocá de nuevo para parar".
    private var silenceTask: Task<Void, Never>?
    private static let silenceThreshold: TimeInterval = 1.0
    /// Polling del audio level para que el UI lo lea. SwiftUI no puede observar
    /// directamente la propiedad de otra clase observable cross-actor sin esto.
    private var levelPollTask: Task<Void, Never>?

    // MARK: - Lifecycle

    /// Setup inicial cuando se abre la pantalla. Pide permisos.
    func start(appState: AppState) async {
        guard !sessionStarted else { return }
        sessionStarted = true
        state = .idle

        // Pre-pedir permisos para que el primer tap no tenga delay.
        let auth = await SpeechRecognizerService.requestAuthorization()
        if auth != .authorized {
            state = .error("Necesito permisos de micrófono y reconocimiento de voz")
        }
    }

    /// Cuando se cierra la pantalla. Limpia estado, NO la history (queremos
    /// que persista si vuelve a abrir voice mode).
    func exit() {
        stopMonitoring()
        speech.stop()
        tts.stop()
        cloudTTS.stop()
        state = .idle
        sessionStarted = false
    }

    /// Reset total — limpia history para empezar conversación nueva.
    func reset() {
        exit()
        conversationHistory.removeAll()
        lastUserUtterance = ""
        lastAssistantResponse = ""
    }

    /// Bridge: copia los últimos turns de la conversación de texto al voice mode.
    /// Útil para que voice mode arranque con contexto del chat.
    func bridgeFrom(messages: [AssistantMessage]) {
        conversationHistory = messages.compactMap { m in
            switch m.role {
            case .user: return m.content.isEmpty ? nil : .user(m.content)
            case .assistant: return m.content.isEmpty ? nil : .assistant(m.content)
            case .system: return nil
            }
        }.suffix(8).map { $0 }
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted, state == .speaking {
            // Si estamos hablando y muteamos, paramos.
            tts.stop()
        }
    }

    // MARK: - Main interaction

    /// Tap del orb central. Comportamiento depende del estado:
    /// - idle / error → empezar a escuchar
    /// - listening → parar de escuchar, mandar al LLM
    /// - thinking → no-op (esperar respuesta)
    /// - speaking → interrumpir TTS y volver a listening
    func userTappedOrb(appState: AppState) async {
        Haptics.play(.impactMedium)

        switch state {
        case .idle, .error:
            await beginListening(appState: appState)

        case .listening:
            await stopListeningAndProcess(appState: appState)

        case .thinking:
            // No interrumpir el thinking — el user espera.
            break

        case .speaking:
            // Interrumpir TTS (cualquiera de los 2) y volver a escuchar inmediatamente.
            tts.stop()
            cloudTTS.stop()
            await beginListening(appState: appState)
        }
    }

    // MARK: - State transitions

    private func beginListening(appState: AppState) async {
        speech.transcript = ""
        speech.lastTranscriptUpdate = Date()
        lastUserUtterance = ""

        let localeId = AppLocaleStorage.effectiveLocale.identifier.replacingOccurrences(of: "_", with: "-")
        do {
            try await speech.start(localeIdentifier: localeId)
            state = .listening

            // Arrancar polling del audio level y del silencio.
            startAudioLevelPolling()
            startSilenceMonitor(appState: appState)
        } catch {
            state = .error("No pude activar el micrófono: \(error.localizedDescription)")
        }
    }

    /// Lee `speech.audioLevel` cada 50ms y lo refleja en `userAudioLevel`.
    /// Suaviza con interpolación para que el orb no salte abruptamente.
    private func startAudioLevelPolling() {
        levelPollTask?.cancel()
        levelPollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let target = self.speech.audioLevel
                // Interpolación: smooth hacia el target, evita jitters.
                let smoothed = self.userAudioLevel * 0.6 + target * 0.4
                self.userAudioLevel = smoothed
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms = 20fps
            }
        }
    }

    /// Loop que revisa cada 200ms si el usuario quedó en silencio durante
    /// `silenceThreshold` segundos. Si sí y hay transcript con contenido,
    /// dispara el processing en una task NUEVA (no en la del monitor) para
    /// evitar self-cancellation cuando llamamos `stopMonitoring()` adentro.
    private func startSilenceMonitor(appState: AppState) {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard self.state == .listening else { return }

                let elapsed = Date().timeIntervalSince(self.speech.lastTranscriptUpdate)
                let hasContent = !self.speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                if hasContent && elapsed >= Self.silenceThreshold {
                    // Silencio detectado con contenido. CRITICAL: no llamamos
                    // `stopListeningAndProcess` directamente — eso cancelaría
                    // ESTA task (vía stopMonitoring), y el FinancialContextBuilder
                    // adentro fallaría con CancellationError ("cancelado").
                    // Spawneamos una task fresca y salimos limpiamente.
                    Task { @MainActor [weak self] in
                        await self?.stopListeningAndProcess(appState: appState)
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }
    }

    /// Cancela los monitors. Importante: si esto se llama desde DENTRO del
    /// silence monitor (auto-VAD trigger), la self-cancellation no afecta
    /// porque ya disparamos el processing en una task separada.
    private func stopMonitoring() {
        silenceTask?.cancel()
        silenceTask = nil
        levelPollTask?.cancel()
        levelPollTask = nil
        userAudioLevel = 0
    }

    private func stopListeningAndProcess(appState: AppState) async {
        stopMonitoring()
        speech.stop()
        let userText = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !userText.isEmpty else {
            state = .idle
            return
        }

        lastUserUtterance = userText
        state = .thinking

        do {
            let context = try await FinancialContextBuilder.build(appState: appState)

            // Voice mode usa Anthropic Claude (con tools) por accuracy.
            // FoundationModels (on-device) tiene limitaciones de calidad y context
            // window que generan respuestas off-topic en voice. Anthropic Haiku 4.5
            // es más lento pero responde correcto y puede consultar transactions/
            // budgets via tools. Mantenemos ElevenLabs streaming para el audio
            // (cola de oraciones con prefetch paralelo).
            if let hid = appState.currentHouseholdId,
               let uid = appState.currentUserId,
               !isMuted {
                if await tryAnthropicResponse(
                    userText: userText,
                    context: context,
                    householdId: hid,
                    userId: uid,
                    appState: appState
                ) {
                    return
                }
                // Si falló (rate limit, no token, etc), cae al fallback.
            }

            // Fallback: AIAssistantService routea a Anthropic o FoundationModels
            // según disponibilidad y configuración del user.
            let response = await AIAssistantService.shared.ask(
                message: userText,
                context: context,
                householdId: appState.currentHouseholdId,
                userId: appState.currentUserId,
                history: conversationHistory,
                voiceMode: true
            )

            conversationHistory.append(.user(userText))
            conversationHistory.append(.assistant(response))
            if conversationHistory.count > 10 {
                conversationHistory = Array(conversationHistory.suffix(10))
            }

            lastAssistantResponse = response

            if isMuted {
                state = .idle
                return
            }

            await speakResponse(response, appState: appState)
        } catch is CancellationError {
            await beginListening(appState: appState)
        } catch {
            state = .error("Error: \(error.localizedDescription)")
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if case .error = state {
                await beginListening(appState: appState)
            }
        }
    }

    /// Resuelve la respuesta con Anthropic Claude (Haiku 4.5). Anthropic no
    /// streamea pero tiene tools y context window grande — responde correcto,
    /// no off-topic. La respuesta completa se splittea en oraciones que se
    /// encolan en el cloud TTS (cada una se fetchea en paralelo con prefetch
    /// de la siguiente, así la pausa entre oraciones es mínima).
    ///
    /// Retorna true si funcionó, false si falló (rate limit, no token, etc).
    private func tryAnthropicResponse(
        userText: String,
        context: FinancialContext,
        householdId: UUID,
        userId: UUID,
        appState: AppState
    ) async -> Bool {
        guard let token = await TokenHolder.shared.get() else {
            return false
        }

        state = .thinking

        let response: String
        do {
            response = try await AnthropicProvider.shared.respond(
                message: userText,
                context: context,
                householdId: householdId,
                userId: userId,
                accessToken: token,
                history: conversationHistory,
                voiceMode: true
            )
        } catch {
            return false
        }

        // Update history.
        conversationHistory.append(.user(userText))
        conversationHistory.append(.assistant(response))
        if conversationHistory.count > 10 {
            conversationHistory = Array(conversationHistory.suffix(10))
        }
        lastAssistantResponse = response

        if isMuted || response.isEmpty {
            state = .idle
            return true
        }

        // Splittear en oraciones y encolar al cloud TTS para que cada una se
        // fetchee en paralelo (mientras suena la N, se descarga la N+1).
        state = .speaking
        let sentences = splitIntoSentences(response)
        for sentence in sentences {
            cloudTTS.enqueue(sentence, accessToken: token)
        }
        await cloudTTS.waitUntilQueueDone()

        if state == .speaking {
            await beginListening(appState: appState)
        }
        return true
    }

    /// Splittea texto en oraciones por puntuación (`. ! ? \n`).
    /// Usado para encolar al cloud TTS y aprovechar el prefetch paralelo.
    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let terminators: Set<Character> = [".", "!", "?", "\n"]
        for ch in text {
            current.append(ch)
            if terminators.contains(ch) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }
        let leftover = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !leftover.isEmpty {
            sentences.append(leftover)
        }
        return sentences
    }

    private func speakResponse(_ text: String, appState: AppState) async {
        state = .speaking

        // Tier 1: Cloud TTS (OpenAI Nova) — voz premium tipo ChatGPT.
        if useCloudTTS, let token = await TokenHolder.shared.get() {
            await speakWithCloudTTS(text, accessToken: token, appState: appState)
            return
        }

        // Tier 2 (fallback): AVSpeechSynthesizer local — robótico pero gratis.
        await speakWithLocalTTS(text, appState: appState)
    }

    private func speakWithCloudTTS(_ text: String, accessToken: String, appState: AppState) async {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                await self.cloudTTS.speak(text, accessToken: accessToken) { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self else {
                            continuation.resume()
                            return
                        }
                        // Si Cloud TTS falló, fallback al local antes de volver a escuchar.
                        if self.cloudTTS.lastError != nil {
                            self.cloudTTS.lastError = nil
                            await self.speakWithLocalTTS(text, appState: appState)
                            continuation.resume()
                            return
                        }
                        if self.state == .speaking {
                            await self.beginListening(appState: appState)
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Helper actor para acumular oraciones recibidas del stream de forma
    /// thread-safe. Usado para reconstruir el texto completo después.
    private actor SentenceCollector {
        var sentences: [String] = []
        func append(_ s: String) {
            sentences.append(s)
        }
        var fullText: String {
            sentences.joined(separator: " ")
        }
    }

    private func speakWithLocalTTS(_ text: String, appState: AppState) async {
        await withCheckedContinuation { continuation in
            tts.speak(text) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else {
                        continuation.resume()
                        return
                    }
                    if self.state == .speaking {
                        await self.beginListening(appState: appState)
                    }
                    continuation.resume()
                }
            }
        }
    }
}
