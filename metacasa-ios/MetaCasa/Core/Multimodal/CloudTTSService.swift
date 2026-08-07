import Foundation
@preconcurrency import AVFoundation
import NaturalLanguage
import Observation

/// Cloud-based TTS via Edge Function `tts-proxy`.
/// Soporta OpenAI TTS y ElevenLabs. API keys viven solo server-side.
@MainActor
@Observable
final class CloudTTSService: NSObject {
    static let shared = CloudTTSService()

    private var audioPlayer: AVAudioPlayer?

    /// Callback del caller de `speak(_:accessToken:onFinish:)`. **Sólo eso.**
    ///
    /// Antes este campo se compartía con `playAndWaitForFinish`, que lo pisaba
    /// con su propia continuación. Como cualquiera de los cuatro caminos que
    /// terminan audio (`stop`, `stopInternal`, los dos delegates de
    /// `AVAudioPlayer`) consume "el handler que haya", uno podía consumir el de
    /// otro flujo: el `catch` de una locución cancelada llamaba al callback de
    /// la SIGUIENTE, la cola resumía la continuación de `speak`, y el callback
    /// del caller quedaba descartado en el camino feliz. De ahí salían tanto
    /// cierres inesperados como el modo voz trabado en `.speaking`.
    private var onFinishHandler: (() -> Void)?

    /// Continuación de la reproducción en curso (`playAndWaitForFinish`), en su
    /// propio canal y protegida contra doble reanudación.
    private var playbackGate: PlaybackGate?

    /// Número de la locución vigente. Ver `speak(_:accessToken:onFinish:)`.
    private var generacion: UInt64 = 0

    /// Una `CheckedContinuation` que varios caminos pueden intentar reanudar.
    ///
    /// Reanudar dos veces una continuación **no es un warning: mata el proceso**
    /// ("SWIFT TASK CONTINUATION MISUSE"). Acá los caminos que pueden querer
    /// cerrarla son genuinamente concurrentes —el audio termina solo, el usuario
    /// toca el orb, se cierra la hoja de voz, arranca otra locución— y no se
    /// puede garantizar por inspección que sólo uno gane. Se garantiza acá:
    /// abrir de más es inofensivo.
    ///
    /// Todo el servicio vive en `@MainActor`, así que alcanza con el flag.
    @MainActor
    private final class PlaybackGate {
        private var cont: CheckedContinuation<Void, Never>?
        init(_ cont: CheckedContinuation<Void, Never>) { self.cont = cont }
        /// Reanuda si nadie lo hizo antes. Idempotente.
        func open() {
            cont?.resume()
            cont = nil
        }
    }

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
    ///
    /// Voces regionales nativas (conversacionales), una por variante de idioma,
    /// para que el ACENTO de la voz coincida con la variante del TEXTO que genera
    /// el modelo (ver `AISystemPromptV2.languageVariantPhrase`). Mucho mejor que
    /// usar una sola voz para todo (p. ej. Malena rioplatense leyendo castellano
    /// o inglés con acento porteño). La selección la hace `resolveVoice(for:)`.
    enum ElevenLabsVoice: String, Sendable, CaseIterable {
        // — Regionales (default por región) —
        /// 🇦🇷 Rioplatense (Buenos Aires), joven, conversacional. es-AR / es-UY.
        case malena = "p7AwDmKvTdoHTBuueGvP"
        /// 🇪🇸 Castellano peninsular, cálida y empática. es-ES.
        case cristinaES = "dNjJKg63Fr5AXwIdkATa"
        /// 🌎 Español latinoamericano neutro (acento mexicano), conversacional. es-419.
        case cristinaCampos = "nTkjq09AuYgsNR8E4sDe"
        /// 🇧🇷 Português do Brasil, formal y clara, conversacional. pt-BR.
        case fernanda = "7iqXtOF3wl3pomwXFY7G"
        /// 🇺🇸 Inglés americano, nítida y directa (la conversacional más usada). en.
        case cassidy = "56AoDkrOh6qfVPDXZ7Pt"
        /// 🇺🇸 Inglés americano, profesional y serena (alternativa a Cassidy). en.
        case juniper = "aMSt68OGf4xUZAnLpTU8"

        // — Premade legacy (fallback / experimentación) —
        case rachel = "21m00Tcm4TlvDq8ikWAM"
        case adam = "pNInz6obpgDQGcFmaJgB"
        case bella = "EXAVITQu4vr4xnSDxMaL"
        case josh = "TxGEqnHWrfWFTfGW9XjX"
        case arnold = "VR6AewLTigWG4xSOukaG"
        case sam = "yoZ06aMxZJJ28mfd3POQ"
        case emily = "LcfcDJNUP1GQjkzn1xUU"

        var displayName: String {
            switch self {
            case .malena: "Malena (es-AR)"
            case .cristinaES: "Cristina (es-ES)"
            case .cristinaCampos: "Cristina Campos (es-419)"
            case .fernanda: "Fernanda (pt-BR)"
            case .cassidy: "Cassidy (en)"
            case .juniper: "Juniper (en)"
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
    /// Cuando es `true` (default), la voz ElevenLabs se elige automáticamente
    /// según el idioma del texto + la región del usuario (decisión: "default por
    /// región"). Poné `false` para forzar `preferredElevenLabsVoice`.
    var autoVoiceByLocale: Bool = true
    /// Override manual de voz cuando `autoVoiceByLocale == false`. También sirve
    /// de fallback histórico (rioplatense) si la detección no resuelve nada.
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
        // Cada locución se numera. Los dos `await` de abajo duran hasta 30 s con
        // red mala, y en ese rato el usuario puede pedir otra cosa: sin este
        // número, el `catch` de la locución VIEJA consumía `onFinishHandler` —que
        // para entonces ya era el de la NUEVA— y lo llamaba. Como el caller
        // (`VoiceConversationManager.speakWithCloudTTS`) envuelve ese callback en
        // una `withCheckedContinuation` y hace `resume()` en cada invocación,
        // eso terminaba reanudando la continuación de otro flujo. Reanudar dos
        // veces no es un warning: es SWIFT TASK CONTINUATION MISUSE y la app
        // muere en el acto.
        // Cerrar la locución anterior ANTES de tomar número: `stopInternal`
        // también incrementa la generación, así que el orden importa. Se avisa
        // al caller viejo (`callFinish: true`): su continuación está esperando y
        // descartarla dejaba el modo voz trabado en `.speaking`.
        if isSpeaking || onFinishHandler != nil {
            stopInternal(callFinish: true)
        }

        generacion &+= 1
        let mia = generacion

        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else {
            onFinish()
            return
        }

        onFinishHandler = onFinish

        do {
            let audioData = try await fetchAudio(text: cleaned, accessToken: accessToken)
            // Llegó tarde: mientras bajaba el audio arrancó otra locución y el
            // canal ya no es nuestro. Reproducir ahora pisaría la suya.
            guard generacion == mia else { return }
            try await play(audioData: audioData)
        } catch {
            lastError = error.localizedDescription
            // Sólo cerramos el canal si SEGUIMOS siendo la locución vigente. Si
            // otra ya tomó el relevo, ella es la dueña de `onFinishHandler` y
            // tocarlo es exactamente el bug que este número evita.
            guard generacion == mia else { return }
            isSpeaking = false
            let handler = onFinishHandler
            onFinishHandler = nil
            handler?()
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

    /// Cierre normal de una reproducción: la terminó el propio player.
    ///
    /// Los dos delegates de `AVAudioPlayer` llegan por acá en vez de repetir la
    /// secuencia cada uno. El `Task { @MainActor }` de los delegates se encola,
    /// así que para cuando esto corre `stopInternal` puede haber pasado ya: por
    /// eso el gate es idempotente y el handler se consume antes de llamarse.
    private func finishPlayback() {
        audioPlayer = nil
        isSpeaking = false
        playbackGate?.open()
        playbackGate = nil
        let handler = onFinishHandler
        onFinishHandler = nil
        handler?()
    }

    private func stopInternal(callFinish: Bool) {
        // Invalida cualquier locución en vuelo. Es lo que evita el choque de
        // sesión de audio: `stop()` NO cancela el `fetchAudio` que está bajando,
        // así que sin esto, un `speak` que el usuario ya interrumpió volvía 20 s
        // después y llamaba `play()` → `setCategory(.playback)` + `setActive(true)`
        // **con el micrófono ya grabando** (el orb reabre `.playAndRecord`), y
        // CoreAudio aborta el proceso. En el simulador no pasa: el input node no
        // es real.
        generacion &+= 1
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        // El gate se abre SIEMPRE, aun con `callFinish: false`: es una
        // continuación suspendida, no un callback opcional. Dejarla sin abrir
        // cuelga a `playAndWaitForFinish` —y con él a toda la cola de oraciones—
        // para siempre. `callFinish` decide sólo si se avisa al caller.
        playbackGate?.open()
        playbackGate = nil
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

                // Entre bajar el audio y reproducirlo pudo pasar un `stop()`, que
                // cancela esta tarea y reabre el micrófono. Reproducir igual
                // reconfigura la sesión a `.playback` con el engine grabando y
                // CoreAudio aborta el proceso. `fetchAudio` no coopera con la
                // cancelación, así que hay que chequear acá.
                if Task.isCancelled { return }

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
            // Canal propio: pisar `onFinishHandler` descartaba el callback del
            // caller de `speak` y mezclaba dos flujos en una sola variable.
            self.playbackGate = PlaybackGate(cont)
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
                voice_id: resolveVoice(for: text).rawValue,
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

    // MARK: - Voice selection (region-aware)

    /// Elige la voz ElevenLabs para un fragmento de texto. Si `autoVoiceByLocale`
    /// está desactivado, respeta `preferredElevenLabsVoice`. Si está activo,
    /// detecta el idioma del TEXTO (on-device, instantáneo) y lo combina con la
    /// región del usuario — el MISMO criterio que la voz on-device
    /// (`TTSService.detectLanguageCode`) y la variante de texto del modelo
    /// (`AISystemPromptV2.languageVariantPhrase`), para que acento y registro no
    /// se contradigan.
    private func resolveVoice(for text: String) -> ElevenLabsVoice {
        guard autoVoiceByLocale else { return preferredElevenLabsVoice }

        let localeLang = AppLocaleStorage.effectiveLocale.language.languageCode?.identifier
        // Si la detección no es confiable, seguimos el idioma del locale.
        guard let lang = detectLanguage(of: text, biasedTo: localeLang) ?? localeLang else {
            return voiceFromLocale()
        }
        switch lang {
        case "es": return spanishVoice()
        case "pt": return .fernanda          // pt-BR (única voz PT disponible)
        case "en": return englishVoice()
        default:   return voiceFromLocale()
        }
    }

    /// Idioma dominante del texto (on-device, NLLanguageRecognizer). Se sesga
    /// hacia `biasLang` (el idioma del usuario) y exige confianza mínima, para
    /// que oraciones cortas o numéricas — el modo voz encola oración por oración —
    /// no disparen cambios de voz a mitad de respuesta. `nil` si no hay señal.
    private func detectLanguage(of text: String, biasedTo biasLang: String?) -> String? {
        let recognizer = NLLanguageRecognizer()
        if let biasLang, let nl = Self.nlLanguage(for: biasLang) {
            recognizer.languageHints = [nl: 0.5]
        }
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage, dominant != .undetermined else {
            return nil
        }
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominant] ?? 0
        return confidence >= 0.55 ? dominant.rawValue : nil
    }

    private static func nlLanguage(for code: String) -> NLLanguage? {
        switch code {
        case "es": return .spanish
        case "pt": return .portuguese
        case "en": return .english
        default:   return nil
        }
    }

    /// Español por región: España→Cristina (castellano), AR/UY→Malena
    /// (rioplatense voseo), resto LatAm→Cristina Campos (neutro). Mismo reparto
    /// que `AISystemPromptV2.languageVariantPhrase` para "es".
    private func spanishVoice() -> ElevenLabsVoice {
        switch AppLocaleStorage.effectiveLocale.region?.identifier {
        case "ES":       return .cristinaES
        case "AR", "UY": return .malena
        default:         return .cristinaCampos
        }
    }

    /// Inglés: Cassidy es el default (la conversacional femenina más usada).
    /// Juniper queda como alternativa profesional vía `preferredElevenLabsVoice`.
    private func englishVoice() -> ElevenLabsVoice { .cassidy }

    /// Fallback cuando el reconocedor no detecta idioma (p. ej. "$1.250"):
    /// usar el idioma del locale efectivo del usuario.
    private func voiceFromLocale() -> ElevenLabsVoice {
        switch AppLocaleStorage.effectiveLocale.language.languageCode?.identifier {
        case "es": return spanishVoice()
        case "pt": return .fernanda
        case "en": return englishVoice()
        default:   return preferredElevenLabsVoice
        }
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
            self?.finishPlayback()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastError = error?.localizedDescription ?? "decode error"
            self.finishPlayback()
        }
    }
}
