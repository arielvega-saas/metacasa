import SwiftUI
import AVFoundation
import Observation

/// Modo voz tipo ChatGPT — conversación bidireccional fluida por audio.
///
/// Características:
/// - **Auto-VAD**: detecta silencio (1.6s) y procesa automáticamente.
/// - **Orb reactivo al volumen**: escala con el RMS del mic en vivo.
/// - **Loop continuo**: después de hablar, vuelve a escuchar solo.
/// - **Interrupción**: tap durante speaking corta el TTS y vuelve a escuchar.
/// - **Stripping de markdown**: en transcripts no se ven `**asteriscos**`.
@MainActor
struct VoiceConversationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var manager = VoiceConversationManager.shared

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 20)
                centerOrb
                Spacer(minLength: 20)
                transcriptionPanel
                bottomHint
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .preferredColorScheme(.dark)
        .task {
            await manager.start(appState: appState)
        }
        .onDisappear {
            manager.exit()
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Sage glow centered, breathing
            RadialGradient(
                colors: [
                    glowColor.opacity(0.30 + 0.15 * Double(manager.userAudioLevel)),
                    glowColor.opacity(0.08),
                    .clear,
                ],
                center: .center,
                startRadius: 60,
                endRadius: 380
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: manager.state)
        }
    }

    private var glowColor: Color {
        switch manager.state {
        case .idle: return .brandPrimary.opacity(0.5)
        case .listening: return .brandPrimary
        case .thinking: return .brandSecondary
        case .speaking: return .brandSuccess
        case .error: return .brandDanger
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                manager.toggleMute()
            } label: {
                Image(systemName: manager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Center orb (reactive to audio level)

    private var centerOrb: some View {
        Button {
            Task { await manager.userTappedOrb(appState: appState) }
        } label: {
            ZStack {
                ringsLayer
                solidOrb
            }
            .frame(width: 220, height: 220)
        }
        .buttonStyle(.plain)
    }

    /// Anillos exteriores que pulsan suavemente. Cuando estamos listening,
    /// uno de ellos refleja el audio level en tiempo real.
    private var ringsLayer: some View {
        ZStack {
            // Outer ring — siempre suave breathing
            Circle()
                .stroke(orbColor.opacity(0.2), lineWidth: 1.5)
                .frame(width: outerRingSize, height: outerRingSize)
                .animation(.easeInOut(duration: 1.2), value: outerRingSize)

            // Mid ring — reactivo al audio level cuando listening
            Circle()
                .stroke(orbColor.opacity(0.35), lineWidth: 2)
                .frame(width: midRingSize, height: midRingSize)
                .animation(.spring(response: 0.15, dampingFraction: 0.7), value: midRingSize)
        }
    }

    private var outerRingSize: CGFloat {
        switch manager.state {
        case .listening: return 290 + CGFloat(manager.userAudioLevel) * 25
        case .thinking, .speaking: return 280
        default: return 270
        }
    }

    private var midRingSize: CGFloat {
        switch manager.state {
        case .listening: return 245 + CGFloat(manager.userAudioLevel) * 35
        case .thinking, .speaking: return 240
        default: return 235
        }
    }

    /// El orb central. Escala suavemente con el audio level en listening,
    /// hace breathing en speaking, queda quieto en thinking.
    private var solidOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            orbColor,
                            orbColor.opacity(0.85),
                        ],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .overlay(
                    Circle().stroke(orbColor.opacity(0.7), lineWidth: 1.5)
                )
                .shadow(color: orbColor.opacity(0.5), radius: 25, x: 0, y: 0)
                .animation(.spring(response: 0.18, dampingFraction: 0.7), value: orbSize)

            // Soft inner highlight
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: orbSize * 0.65, height: orbSize * 0.65)
                .offset(x: -orbSize * 0.12, y: -orbSize * 0.12)
                .blur(radius: 20)

            // Status icon (solo en idle/thinking — no en listening/speaking)
            if let icon = orbIcon {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color(hex: "#0E1312"))
                    .symbolEffect(.pulse, options: .repeating, value: manager.state == .thinking)
            }
        }
    }

    private var orbSize: CGFloat {
        switch manager.state {
        case .idle, .error: return 180
        case .listening: return 180 + CGFloat(manager.userAudioLevel) * 25
        case .thinking: return 175
        case .speaking: return 195
        }
    }

    private var orbColor: Color {
        switch manager.state {
        case .idle: return .brandPrimary.opacity(0.85)
        case .listening: return .brandPrimary
        case .thinking: return .brandSecondary
        case .speaking: return .brandSuccess
        case .error: return .brandDanger
        }
    }

    /// Solo mostramos icon en idle/thinking/error. En listening y speaking
    /// el orb mismo es la animación principal — un icon distrae.
    private var orbIcon: String? {
        switch manager.state {
        case .idle: return "mic.fill"
        case .thinking: return "sparkles"
        case .error: return "exclamationmark.triangle.fill"
        case .listening, .speaking: return nil
        }
    }

    // MARK: - Transcription panel (clean, markdown-stripped)

    private var transcriptionPanel: some View {
        VStack(spacing: 10) {
            if !manager.lastUserUtterance.isEmpty {
                Text(stripMarkdown(manager.lastUserUtterance))
                    .font(.callout)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }
            if !manager.lastAssistantResponse.isEmpty {
                Text(stripMarkdown(manager.lastAssistantResponse))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxHeight: 160)
        .padding(.horizontal, 8)
    }

    /// Quita los `**bold**`, `*italic*`, `[links]()`, backticks y emojis.
    /// Es el mismo tratamiento que TTSService aplica antes de hablar — coherente.
    private func stripMarkdown(_ text: String) -> String {
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
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Bottom hint (subtle, contextual)

    private var bottomHint: some View {
        Text(bottomHintText)
            .font(.caption)
            .foregroundStyle(Color.textMuted.opacity(0.7))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .opacity(manager.state == .listening || manager.state == .speaking ? 0 : 1)
            .animation(.easeInOut(duration: 0.4), value: manager.state)
    }

    private var bottomHintText: String {
        switch manager.state {
        case .idle: return "Tocá el círculo y empezá a hablar"
        case .listening: return ""
        case .thinking: return "Procesando…"
        case .speaking: return ""
        case .error(let msg): return msg
        }
    }
}
