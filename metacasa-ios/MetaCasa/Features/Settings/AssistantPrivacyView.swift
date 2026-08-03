import SwiftUI

/// Configuración de privacidad del Asistente IA.
///
/// Tres acciones del usuario:
/// 1. Toggle "Procesamiento en la nube" — alterna `assistantCloudConsent`.
///    Cuando OFF, el asistente solo usa FoundationModels on-device (iOS 26+)
///    o el statistical fallback. Garantiza que ningún dato sale del iPhone.
/// 2. Toggle "Solo on-device" — alterna `assistantOnDeviceOnly` (visible
///    solo si consent está ON). Útil para sesiones donde el user prefiere
///    privacidad absoluta temporalmente sin revocar el consent global.
/// 3. Botón "Revocar consentimiento y borrar historial" — resetea consent
///    y limpia los chat-sessions del hogar activo. La próxima apertura del
///    chat muestra de nuevo el sheet de consent.
struct AssistantPrivacyView: View {
    @Environment(PrivacyManager.self) private var privacy
    @Environment(AppState.self) private var appState
    @State private var showRevokeConfirm = false

    var body: some View {
        @Bindable var p = privacy

        ScrollView {
            VStack(spacing: 22) {
                header
                cloudToggleCard(cloudConsent: $p.assistantCloudConsent)
                if p.assistantCloudConsent {
                    onDeviceToggleCard(onDeviceOnly: $p.assistantOnDeviceOnly)
                }
                explanationCard
                revokeButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(Text("Privacidad del Asistente"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "¿Revocar consentimiento y borrar historial del Asistente?",
            isPresented: $showRevokeConfirm,
            titleVisibility: .visible
        ) {
            Button("Revocar y borrar", role: .destructive) {
                Task { await revokeAndClear() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Vas a borrar el historial guardado del Asistente IA en este hogar. La próxima vez que abras el chat, te pedimos consentimiento de nuevo.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.18))
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.shield.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.brandPrimary)
            }
            Text("Vos decidís qué pasa con tu data")
                .font(.mcSerifTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("Estos controles son inmediatos y persistentes — los respetamos en todos los modos (chat, voz, vision).")
                .font(.mcCaption)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.top, 8)
    }

    private func cloudToggleCard(cloudConsent: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "cloud")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.brandPrimary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Procesamiento en la nube")
                        .font(.mcBody.weight(.bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Permite usar Claude (Anthropic) para consultas complejas.")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textMuted)
                }
                Spacer()
                Toggle("", isOn: cloudConsent)
                    .labelsHidden()
                    .tint(Color.brandPrimary)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func onDeviceToggleCard(onDeviceOnly: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.brandPrimary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Forzar solo on-device")
                        .font(.mcBody.weight(.bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("El asistente usa solo Apple Intelligence on-device. Más lento, pero ningún dato sale del iPhone.")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: onDeviceOnly)
                    .labelsHidden()
                    .tint(Color.brandPrimary)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("assistantPrivacy.section.whatWeProcess")
                    .font(.mcLabel)
                    .foregroundStyle(Color.textMuted)
                VStack(alignment: .leading, spacing: 8) {
                    bullet("Reconocimiento de voz y OCR de recibos siempre on-device (Apple Speech + Vision).")
                    bullet("Si activás cloud: tus mensajes y transcripciones de voz, un resumen de tus finanzas (montos, categorías, saldos) y las fotos de recibos que escanees van a Claude. Nunca emails, ni tarjetas, ni contraseñas.")
                    bullet("Anthropic NO entrena modelos con consultas de su API.")
                    bullet("Tus conversaciones se guardan localmente en tu iPhone (encriptado). Podés borrarlas desde acá.")
                }
            }

            Divider().background(Color.appBorder)

            VStack(alignment: .leading, spacing: 10) {
                Text("assistantPrivacy.section.thirdParties")
                    .font(.mcLabel)
                    .foregroundStyle(Color.textMuted)
                VStack(alignment: .leading, spacing: 10) {
                    serviceRow(
                        name: "Anthropic (Claude)",
                        purpose: "LLM del Asistente IA (chat, voz, visión).",
                        dataSent: "Mensajes y transcripciones de voz, resumen de tus finanzas, y fotos de recibos que escanees."
                    )
                    serviceRow(
                        name: "ElevenLabs",
                        purpose: "Síntesis de voz (TTS) cuando usás el modo voz.",
                        dataSent: "Solo el texto de la respuesta del asistente."
                    )
                    serviceRow(
                        name: "Apple Speech + Vision",
                        purpose: "Reconocimiento de voz y OCR de recibos.",
                        dataSent: "Procesado on-device. Nada sale del iPhone."
                    )
                }
            }
        }
        .padding(16)
        .background(Color.appSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// `name` queda `String` a propósito: "Anthropic (Claude)", "ElevenLabs" y "Apple Speech +
    /// Vision" son nombres propios y no se traducen. `purpose` y `dataSent` sí, y la etiqueta
    /// "Datos enviados" va como formato —no concatenada— porque en otros idiomas el orden de las
    /// dos partes no tiene por qué ser el mismo.
    private func serviceRow(name: String, purpose: LocalizedStringKey, dataSent: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: name)
                .font(.mcBody.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            Text(purpose)
                .font(.mcCaption)
                .foregroundStyle(Color.textMuted)
            Text("Datos enviados: \(Text(dataSent))")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var revokeButton: some View {
        Button {
            showRevokeConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Revocar consentimiento y borrar historial")
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.brandDanger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.brandDanger.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// `LocalizedStringKey`, no `String`: con `String` Swift elige `Text(_ verbatim:)` y el texto
    /// sale sin pasar por el catálogo. Esta es la pantalla que App Review lee para el disclosure
    /// de IA — tiene que estar en el idioma del usuario, no en el mío.
    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(Color.brandPrimary)
            Text(text)
                .font(.mcCaption)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func revokeAndClear() async {
        // Revocar consent global
        privacy.assistantCloudConsent = false
        privacy.assistantOnDeviceOnly = false
        // Borrar history persistido del hogar activo
        if let hid = appState.currentHouseholdId {
            await ChatPersistenceService.shared.clearAll(householdId: hid)
        }
        // Reset del view model en RAM
        AssistantViewModel.shared.messages = []
        Haptics.play(.success)
    }
}
