import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation
import Observation

/// Dictado on-device via SFSpeechRecognizer + AVAudioEngine.
/// Observable — el caller (AssistantChatView) observa `transcript` para ver
/// el texto mientras el usuario habla, y `isRecording` para el UI del mic.
///
/// Requiere permisos en Info.plist:
///   - NSSpeechRecognitionUsageDescription
///   - NSMicrophoneUsageDescription
///
/// Privacidad: `requiresOnDeviceRecognition = true` fuerza que el
/// reconocimiento corra localmente en iOS 13+. Sin conexión a Apple.
@MainActor
@Observable
final class SpeechRecognizerService {
    static let shared = SpeechRecognizerService()
    private init() {}

    enum AuthState: Sendable {
        case notDetermined, denied, restricted, authorized
    }

    var isRecording: Bool = false
    var transcript: String = ""
    var errorMessage: String?
    /// Nivel de audio normalizado 0.0–1.0. Actualizado en cada buffer del mic.
    /// El UI lo usa para animar el orb del voice mode reactivamente.
    var audioLevel: Float = 0.0
    /// Timestamp del último cambio en el transcript. Usado por el manager para
    /// detectar silencio (auto-VAD) y procesar automáticamente.
    var lastTranscriptUpdate: Date = Date()

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Pide permiso de Speech + Microphone. Retorna el estado combinado.
    /// Importante: si los permisos ya fueron decididos (authorized/denied/restricted),
    /// NO re-pedimos (evita un crash observado en iOS 26 donde el callback de
    /// `SFSpeechRecognizer.requestAuthorization` puede dispararse 2x y double-resume
    /// la continuation, matando la app con SIGTRAP).
    static func requestAuthorization() async -> AuthState {
        print("[Speech] requestAuthorization start")
        let speechStatus = await awaitSpeechAuth()
        print("[Speech] speech status: \(speechStatus.rawValue)")

        let micGranted = await awaitMicAuth()
        print("[Speech] mic granted: \(micGranted)")

        guard micGranted else { return .denied }

        switch speechStatus {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private static func awaitSpeechAuth() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        if current != .notDetermined { return current }

        // Wrapper de la callback API con un Atomic-like flag para descartar
        // resumes duplicadas que iOS 26 reporta en algunos builds.
        let box = ResumeOnce<SFSpeechRecognizerAuthorizationStatus>()
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                box.resumeOnce(cont, with: status)
            }
        }
    }

    private static func awaitMicAuth() async -> Bool {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return true
            case .denied: return false
            case .undetermined: return await AVAudioApplication.requestRecordPermission()
            @unknown default: return false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted: return true
            case .denied: return false
            case .undetermined:
                let box = ResumeOnce<Bool>()
                return await withCheckedContinuation { cont in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        box.resumeOnce(cont, with: granted)
                    }
                }
            @unknown default: return false
            }
        }
    }

    func start(localeIdentifier: String = "es-AR") async throws {
        print("[Speech] start: locale=\(localeIdentifier) isRecording=\(isRecording)")
        guard !isRecording else { return }
        errorMessage = nil
        transcript = ""

        // Cleanup defensivo: si un run anterior dejó el engine corriendo o un tap
        // colgado, `installTap` abajo crashea con NSException no-cacheable.
        print("[Speech] cleanup audio engine")
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        print("[Speech] init SFSpeechRecognizer")
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        guard let recognizer, recognizer.isAvailable else {
            print("[Speech] recognizer unavailable")
            throw NSError(
                domain: "Speech",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "El reconocimiento de voz no está disponible en este dispositivo o idioma."]
            )
        }
        print("[Speech] recognizer ok, supportsOnDevice=\(recognizer.supportsOnDeviceRecognition)")

        let audioSession = AVAudioSession.sharedInstance()
        print("[Speech] setCategory")
        // `.playAndRecord` + `.default` es más tolerante que `.record` + `.measurement`,
        // que en iOS 26 puede fallar la activación cuando hay otro audio activo.
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
        )
        print("[Speech] setActive(true)")
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        print("[Speech] session active")

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // NOTA: `requiresOnDeviceRecognition = true` lo dejamos en false (default).
        // En iOS 26 algunos devices reportan `supportsOnDeviceRecognition = true`
        // pero el modelo aún no está descargado y el primer recognitionTask
        // crashea con SIGTRAP en un thread interno sin opción a recover.
        // Con on-device en false, Apple usa cloud transcription transparentemente
        // y la UX es la misma para el usuario.
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        print("[Speech] inputNode format sr=\(format.sampleRate) ch=\(format.channelCount)")

        // Si el mic todavía no está listo, `installTap` crashea con
        // "required condition is false: format.sampleRate > 0". Lanzamos
        // un error legible en vez de abortar la app.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            recognitionRequest = nil
            throw NSError(
                domain: "Speech",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "El micrófono no está listo. Cerrá apps que lo estén usando y probá de nuevo."]
            )
        }

        print("[Speech] recognitionTask")
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let newTranscript = result.bestTranscription.formattedString
                    if newTranscript != self.transcript {
                        self.transcript = newTranscript
                        self.lastTranscriptUpdate = Date()
                    }
                    if result.isFinal {
                        self.stop()
                    }
                }
                if let error {
                    if self.transcript.isEmpty {
                        self.errorMessage = error.localizedDescription
                    }
                    self.stop()
                }
            }
        }

        print("[Speech] installTap")
        // IMPORTANTE: el callback de installTap se invoca desde un audio render
        // thread (NO MainActor). El SpeechTapHandler vive fuera del MainActor
        // así Swift 6 no aplica check de isolation. Computa audio level (RMS)
        // del buffer y lo manda de vuelta al servicio via callback.
        let tapHandler = SpeechTapHandler(request: request) { [weak self] level in
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapHandler.block)

        print("[Speech] audioEngine.prepare + start")
        audioEngine.prepare()
        try audioEngine.start()
        print("[Speech] RECORDING")
        isRecording = true
    }

    func stop() {
        // Marcamos isRecording=false primero — si algún cleanup tira NSException,
        // al menos el estado de UI queda consistente.
        let wasRecording = isRecording
        isRecording = false
        guard wasRecording else { return }

        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stop()
        transcript = ""
        errorMessage = nil
    }
}

/// Wrapper non-isolated para el callback de `AVAudioEngine.installTap`.
///
/// El callback de installTap se invoca desde un audio render thread. Como
/// `SpeechRecognizerService.start()` es `@MainActor`, cualquier closure
/// declarado inline ahí es inferido como `@MainActor`-isolated por Swift 6,
/// y crashea con SIGTRAP cuando AVFAudio lo invoca desde el audio thread.
///
/// Esta clase vive fuera del actor MainActor → su `block` es nonisolated
/// por construcción → Swift 6 no aplica check de isolation y no crashea.
///
/// `SFSpeechAudioBufferRecognitionRequest.append(_:)` es thread-safe per la
/// doc de Apple. Marcamos `@unchecked Sendable` para certificarlo a Swift.
final class SpeechTapHandler: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest
    private let onAudioLevel: (@Sendable (Float) -> Void)?

    init(
        request: SFSpeechAudioBufferRecognitionRequest,
        onAudioLevel: (@Sendable (Float) -> Void)? = nil
    ) {
        self.request = request
        self.onAudioLevel = onAudioLevel
    }

    /// Closure listo para pasar a `installTap`. Computa RMS amplitude del buffer
    /// como audio level normalizado 0.0–1.0 (con curva sensible al rango de voz).
    var block: AVAudioNodeTapBlock {
        let r = request
        let levelCb = onAudioLevel
        return { buffer, _ in
            r.append(buffer)
            if let cb = levelCb {
                let level = Self.computeLevel(buffer)
                cb(level)
            }
        }
    }

    /// Computa el nivel de audio (RMS) del buffer y lo escala a 0–1 con curva
    /// que enfatiza el rango típico de voz humana (-50 a -10 dBFS).
    private static func computeLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<frames {
            let v = channelData[i]
            sum += v * v
        }
        let rms = sqrt(sum / Float(frames))
        // Convertir a dBFS y normalizar.
        let db = 20 * log10(max(rms, 0.000001))
        // -50 dB = silencio, -10 dB = voz normal. Escalamos a 0–1.
        let clamped = max(-50, min(-10, db))
        return (clamped + 50) / 40
    }
}

/// Permite que una `CheckedContinuation` se resume exactamente una vez aunque
/// el callback de la API de Apple se dispare más de una vez (bug observado en
/// iOS 26 con `SFSpeechRecognizer.requestAuthorization`).
final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func resumeOnce(_ cont: CheckedContinuation<T, Never>, with value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        cont.resume(returning: value)
    }
}
