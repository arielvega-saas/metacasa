import Foundation
@preconcurrency import AVFoundation
import Observation

/// Cloud-based TTS via Edge Function `tts-proxy`.
/// Soporta OpenAI TTS y ElevenLabs. API keys viven solo server-side.
@MainActor
@Observable
final class CloudTTSService: NSObject {
    static let shared = CloudTTSService()

    private var audioPlayer: AVAudioPlayer?
    private var onFinishHandler: (() -> Void)?

    var isSpeaking: Bool = false
    var lastError: String?

    enum Provider: String, Sendable, CaseIterable {
        case openai = "openai"
        case elevenlabs = "elevenlabs"
    }

    enum Voice: String, Sendable, CaseIterable {
        // OpenAI
        case nova = "nova"
        case shimmer = "shimmer"
        case alloy = "alloy"
        case echo = "echo"
        case fable = "fable"
        case onyx = "onyx"
    }

    /// ElevenLabs voices — voice_id + display name.
    /// Malena = voz nativa rioplatense (Buenos Aires), conversacional, joven.
    /// Para español argentino es mucho mejor que las voces inglesas premade
    /// (Rachel/Adam/etc.) que hablan español con acento gringo.
    enum ElevenLabsVoice: String, Sendable, CaseIterable {
        case malena = "p7AwDmKvTdoHTBuueGvP"
        case rachel = "21m00Tcm4TlvDq8ikWAM"
        case adam = "pNInz6obpgDQGcFmaJgB"
        case bella = "EXAVITQu4vr4xnSDxMaL"
        case josh = "TxGEqnHWrfWFTfGW9XjX"
        case arnold = "VR6AewLTigWG4xSOukaG"
        case sam = "yoZ06aMxZJJ28mfd3POQ"
        case emily = "LcfcDJNUP1GQjkzn1xUU"

        var displayName: String {
            switch self {
            case .malena: "Malena (AR)"
            case .rachel: "Rachel"
            case .adam: "Adam"
            case .bella: "Bella"
            case .josh: "Josh"
            case .arnold: "Arnold"
            case .sam: "Sam"
            case .emily: "Emily"
            }
        }
    }

    var provider: Provider = .elevenlabs
    var preferredVoice: Voice = .nova
    // Malena: voz nativa rioplatense. Requiere ElevenLabs Starter+ ($6/mes).
    var preferredElevenLabsVoice: ElevenLabsVoice = .malena

    // MARK: - Sentence queue (streaming-style playback)

    private var sentenceQueue: [String] = []
    private var prefetchedAudio: [String: Data] = [:]
    private var queueProcessor: Task<Void, Never>?
    private var queueAccessToken: String?
    private var queueWaiters: [CheckedContinuation<Void, Never>] = []

    private override init() {
        super.init()
    }

    /// Convierte texto a audio via OpenAI TTS y lo reproduce.
    /// `onFinish` se invoca cuando termina el audio (o cuando se interrumpe).
    func speak(
        _ text: String,
        accessToken: String,
        onFinish: @escaping @Sendable () -> Void
    ) async {
        // Cancelar reproducción previa
        if isSpeaking {
            stopInternal(callFinish: false)
        }

        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else {
            onFinish()
            return
        }

        self.onFinishHandler = onFinish

        do {
            let audioData = try await fetchAudio(text: cleaned, accessToken: accessToken)
            try await play(audioData: audioData)
        } catch {
            lastError = error.localizedDescription
            isSpeaking = false
            onFinishHandler = nil
            onFinish()
        }
    }

    /// Detiene la reproducción inmediatamente. Dispara `onFinish` y limpia
    /// la cola de oraciones (si la hay).
    func stop() {
        sentenceQueue.removeAll()
        prefetchedAudio.removeAll()
        queueProcessor?.cancel()
        queueProcessor = nil
        queueAccessToken = nil
        let waiters = queueWaiters
        queueWaiters.removeAll()
        for w in waiters { w.resume() }
        stopInternal(callFinish: true)
    }

    private func stopInternal(callFinish: Bool) {
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        let handler = onFinishHandler
        onFinishHandler = nil
        if callFinish { handler?() }
    }

    // MARK: - Sentence queue API

    /// Encola una oración para que la diga ElevenLabs en orden.
    /// Mientras la oración N suena, la N+1 ya se está fetcheando en paralelo —
    /// resultado: pausa imperceptible entre oraciones (estilo ChatGPT voice).
    func enqueue(_ text: String, accessToken: String) {
        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else { return }

        queueAccessToken = accessToken
        sentenceQueue.append(cleaned)

        // Empezar prefetch eager para la oración recién encolada si nadie está
        // procesando todavía O si es la siguiente después de la actual.
        startPrefetchIfPossible()

        if queueProcessor == nil {
            startQueueProcessor()
        }
    }

    /// Espera hasta que la cola se vacíe y termine de hablar la última oración.
    func waitUntilQueueDone() async {
        if queueProcessor == nil && sentenceQueue.isEmpty {
            return
        }
        await withCheckedContinuation { cont in
            queueWaiters.append(cont)
        }
    }

    private func startPrefetchIfPossible() {
        guard let token = queueAccessToken else { return }
        // Prefetch hasta 2 oraciones por delante para amortizar latencia.
        let toPrefetch = sentenceQueue.prefix(2)
        for sentence in toPrefetch where prefetchedAudio[sentence] == nil {
            // Marcar como "in flight" con Data() vacío (no, mejor usar otra estrategia).
            // Usamos una task fire-and-forget que guarda en el dict cuando termina.
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Si ya está cacheado mientras tanto, skip.
                if self.prefetchedAudio[sentence] != nil { return }
                if let audio = try? await self.fetchAudio(text: sentence, accessToken: token) {
                    self.prefetchedAudio[sentence] = audio
                }
            }
        }
    }

    private func startQueueProcessor() {
        queueProcessor = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.queueProcessor = nil
                let waiters = self.queueWaiters
                self.queueWaiters.removeAll()
                for w in waiters { w.resume() }
            }

            while !Task.isCancelled {
                guard !self.sentenceQueue.isEmpty else { return }
                guard let token = self.queueAccessToken else { return }

                let sentence = self.sentenceQueue.removeFirst()

                // Trigger prefetch para las próximas mientras esta suena.
                self.startPrefetchIfPossible()

                let audioData: Data
                do {
                    if let cached = self.prefetchedAudio.removeValue(forKey: sentence) {
                        audioData = cached
                    } else {
                        audioData = try await self.fetchAudio(text: sentence, accessToken: token)
                    }
                } catch {
                    self.lastError = error.localizedDescription
                    return
                }

                do {
                    try await self.playAndWaitForFinish(audioData: audioData)
                } catch {
                    self.lastError = error.localizedDescription
                    return
                }

                if Task.isCancelled { return }
            }
        }
    }

    /// Reproduce un buffer de audio y suspende hasta que termine (o se interrumpa).
    private func playAndWaitForFinish(audioData: Data) async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: [])

        let player = try AVAudioPlayer(data: audioData)
        player.delegate = self
        player.prepareToPlay()
        audioPlayer = player
        isSpeaking = true

        await withCheckedContinuation { cont in
            self.onFinishHandler = {
                cont.resume()
            }
            player.play()
        }
    }

    // MARK: - Network

    private func fetchAudio(text: String, accessToken: String) async throws -> Data {
        let url = Config.supabaseURL.appendingPathComponent("functions/v1/tts-proxy")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.timeoutInterval = 30

        let bodyData: Data
        switch provider {
        case .openai:
            struct OpenAIBody: Encodable {
                let text: String
                let provider: String
                let voice: String
                let model: String
            }
            bodyData = try JSONEncoder().encode(OpenAIBody(
                text: text,
                provider: "openai",
                voice: preferredVoice.rawValue,
                model: "tts-1"
            ))
        case .elevenlabs:
            struct ElevenLabsBody: Encodable {
                let text: String
                let provider: String
                let voice_id: String
                let el_model: String
                let stability: Double
                let similarity_boost: Double
                let style: Double
            }
            // stability 0.45 = balance entre estable y expresivo en español.
            // style 0.15 = un toque de variación tonal sin sobreactuar.
            // similarity_boost 0.85 = fidelidad alta a la voz original.
            bodyData = try JSONEncoder().encode(ElevenLabsBody(
                text: text,
                provider: "elevenlabs",
                voice_id: preferredElevenLabsVoice.rawValue,
                el_model: "eleven_flash_v2_5",
                stability: 0.45,
                similarity_boost: 0.85,
                style: 0.15
            ))
        }
        req.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "CloudTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida"])
        }
        if http.statusCode == 429 {
            throw NSError(domain: "CloudTTS", code: 429, userInfo: [NSLocalizedDescriptionKey: "Llegaste al límite diario de uso del asistente"])
        }
        if http.statusCode >= 400 {
            let detail = String(data: data, encoding: .utf8) ?? "?"
            throw NSError(domain: "CloudTTS", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "TTS falló (HTTP \(http.statusCode)): \(detail)"])
        }
        return data
    }

    // MARK: - Playback

    private func play(audioData: Data) async throws {
        // Configurar audio session para playback (no record).
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: [])

        let player = try AVAudioPlayer(data: audioData)
        player.delegate = self
        player.prepareToPlay()
        audioPlayer = player
        isSpeaking = true
        player.play()
    }

    // MARK: - Helpers

    /// Misma lógica que TTSService — strip markdown + emojis para que no
    /// se lean literal.
    private func cleanForSpeech(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(
            of: #"\*([^*\n]+)\*"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "`", with: "")
        let emojiPattern = #"[\u{1F300}-\u{1F9FF}\u{2600}-\u{27BF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}]"#
        result = result.replacingOccurrences(of: emojiPattern, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "→", with: " a ")
        result = result.replacingOccurrences(of: "·", with: ", ")
        result = result.replacingOccurrences(of: "—", with: ", ")

        // Códigos ISO → palabras (red de seguridad). Misma lógica que TTSService.
        let isoMappings: [(String, String)] = [
            ("ARS", "pesos"),
            ("CLP", "pesos"),
            ("COP", "pesos"),
            ("MXN", "pesos"),
            ("UYU", "pesos"),
            ("USD", "dólares"),
            ("EUR", "euros"),
            ("BRL", "reales"),
            ("GBP", "libras"),
            ("JPY", "yenes"),
            ("PEN", "soles"),
        ]
        for (iso, spoken) in isoMappings {
            result = result.replacingOccurrences(
                of: "\\b\(iso)\\b",
                with: spoken,
                options: .regularExpression
            )
        }
        result = result.replacingOccurrences(of: "\n\n", with: ". ")
        result = result.replacingOccurrences(of: "\n", with: ". ")
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AVAudioPlayerDelegate

extension CloudTTSService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.audioPlayer = nil
            self.isSpeaking = false
            let handler = self.onFinishHandler
            self.onFinishHandler = nil
            handler?()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.audioPlayer = nil
            self.isSpeaking = false
            self.lastError = error?.localizedDescription ?? "decode error"
            let handler = self.onFinishHandler
            self.onFinishHandler = nil
            handler?()
        }
    }
}
