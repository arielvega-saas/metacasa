import Foundation
@preconcurrency import AVFoundation
import Observation
import NaturalLanguage

/// Text-to-speech on-device usando `AVSpeechSynthesizer`.
///
/// 100% offline, sin costo, sin tracking. Voces de Apple para 30+ idiomas.
/// La calidad es decente para iOS 17+ con voces "Premium" (descarga gratuita
/// desde Ajustes → Accesibilidad → Contenido leído → Voces).
///
/// Detecta automáticamente el idioma del texto via `NLLanguageRecognizer`
/// y usa la voz correspondiente. Strips markdown y emojis para que no se
/// lean literal ("asterisco asterisco").
@MainActor
@Observable
final class TTSService: NSObject {
    static let shared = TTSService()

    /// AVSpeechSynthesizer es safe en main thread. Marcamos non-Sendable
    /// porque la instancia no se mueve entre actors.
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool = false

    /// Callback cuando termina de hablar (natural o cancelado).
    /// El VoiceConversationManager lo usa para volver a `listening` automáticamente.
    private var onFinishHandler: (() -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Habla el texto con la voz adecuada para el idioma detectado.
    /// Si ya hay un utterance en curso, lo cancela y empieza el nuevo.
    func speak(_ text: String, language: String? = nil, onFinish: (@Sendable () -> Void)? = nil) {
        // Cancelar utterance previo si lo hay.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else {
            onFinish?()
            return
        }

        self.onFinishHandler = onFinish

        let utterance = AVSpeechUtterance(string: cleaned)
        let langCode = language ?? detectLanguageCode(for: cleaned)
        if let voice = bestVoice(for: langCode) {
            utterance.voice = voice
        }

        // Configurar audio session para PLAYBACK (no record). Esto asegura
        // que el speech salga por el speaker incluso con el switch de silencio.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("[TTS] audio session config failed: \(error)")
        }

        // Velocidad ligeramente más lenta que default — más comprensible para finanzas.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Encola una oración. AVSpeechSynthesizer las reproduce en orden FIFO.
    /// Si no hay nada hablando, empieza inmediatamente. Si ya hay queue, se
    /// agrega al final. Usado en el flow streaming para alimentar oraciones
    /// según las genera el LLM.
    func enqueue(_ text: String, language: String? = nil) {
        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else { return }

        // Configurar audio session una sola vez (la primera utterance).
        if !isSpeaking {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try session.setActive(true, options: [])
            } catch {
                print("[TTS] audio session config failed: \(error)")
            }
        }

        let utterance = AVSpeechUtterance(string: cleaned)
        let langCode = language ?? detectLanguageCode(for: cleaned)
        if let voice = bestVoice(for: langCode) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Espera hasta que el queue de utterances esté vacío. Usado por el flow
    /// streaming para saber cuándo la respuesta completa terminó de hablar.
    func waitUntilDone() async {
        while synthesizer.isSpeaking {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        isSpeaking = false
    }

    /// Detiene el speech inmediatamente. Dispara `onFinishHandler` si estaba seteado.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        let handler = onFinishHandler
        onFinishHandler = nil
        handler?()
    }

    /// Pausa (no cancela). Para uso futuro — interrumpir momentáneamente.
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    // MARK: - Helpers

    /// Quita markdown, emojis y caracteres que se leerían literalmente.
    private func cleanForSpeech(_ text: String) -> String {
        var result = text

        // **bold** → bold
        result = result.replacingOccurrences(of: "**", with: "")
        // *italic* → italic (cuidado: no romper conjugaciones tipo "más*" en frases)
        // Usamos regex para matchear solo asteriscos rodeando palabras.
        result = result.replacingOccurrences(
            of: #"\*([^*\n]+)\*"#,
            with: "$1",
            options: .regularExpression
        )
        // [text](url) → text
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        // ` and ``` (code) → quitar backticks
        result = result.replacingOccurrences(of: "`", with: "")

        // Normalizar emojis: los reemplazamos por nada (no se leen, pero pueden
        // generar pausas raras). Más conservador que stripear todo unicode.
        let emojiPattern = #"[\u{1F300}-\u{1F9FF}\u{2600}-\u{27BF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}]"#
        result = result.replacingOccurrences(of: emojiPattern, with: "", options: .regularExpression)

        // Symbols comunes que se leerían mal
        result = result.replacingOccurrences(of: "→", with: " ")
        result = result.replacingOccurrences(of: "·", with: ", ")
        result = result.replacingOccurrences(of: "—", with: ", ")
        result = result.replacingOccurrences(of: "–", with: ", ")

        // Códigos ISO de moneda → palabras habladas (red de seguridad por si
        // el LLM se olvida del system prompt y dice "ARS" en vez de "pesos").
        // Word-boundary regex para no romper palabras que contengan estas letras.
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

        // Múltiples newlines → un punto + espacio
        result = result.replacingOccurrences(of: "\n\n", with: ". ")
        result = result.replacingOccurrences(of: "\n", with: ". ")

        // Limpiar dobles espacios resultantes
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Detecta idioma con NLLanguageRecognizer (on-device, instant).
    /// Retorna BCP-47 code para AVSpeechSynthesisVoice (ej. "es-AR", "en-US").
    private func detectLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let lang = recognizer.dominantLanguage else {
            return AppLocaleStorage.effectiveLocale.identifier.replacingOccurrences(of: "_", with: "-")
        }
        // Mapear códigos a locales con voces de buena calidad.
        switch lang.rawValue {
        case "es": return "es-AR"   // voseo argentino
        case "en": return "en-US"
        case "pt": return "pt-BR"
        case "fr": return "fr-FR"
        case "it": return "it-IT"
        case "de": return "de-DE"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "zh": return "zh-CN"
        default: return lang.rawValue
        }
    }

    /// Encuentra la mejor voz instalada para el idioma. Prioriza Premium > Enhanced > Default.
    private func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        // Primero matchea código exacto (es-AR), si no, fallback a base (es).
        let baseLang = String(language.prefix(2))

        let matching = voices.filter { v in
            v.language == language || v.language.hasPrefix("\(baseLang)-")
        }

        // Premium quality si está descargada (iOS 17+).
        if let premium = matching.first(where: { $0.quality == .premium }) {
            return premium
        }
        // Enhanced (Siri-quality, requiere descarga manual).
        if let enhanced = matching.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        // Default si nada mejor.
        if let exact = matching.first(where: { $0.language == language }) {
            return exact
        }
        return matching.first ?? AVSpeechSynthesisVoice(language: language)
    }
}

// MARK: - Delegate

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            let handler = self.onFinishHandler
            self.onFinishHandler = nil
            handler?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            let handler = self.onFinishHandler
            self.onFinishHandler = nil
            handler?()
        }
    }
}
