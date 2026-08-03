import SwiftUI

/// Sheet de consentimiento explícito para que el Asistente IA pueda enviar
/// consultas al cloud LLM (Claude vía Anthropic). Se muestra la PRIMERA vez
/// que el usuario abre el chat del asistente.
///
/// **Por qué existe**:
/// - Apple Store Review Guideline 5.1.1 (Data Collection) exige consent
///   explícito antes de enviar datos del usuario a servicios de terceros.
/// - GDPR / CCPA / LFPDPPP / LGPD: el procesamiento de datos personales
///   requiere base legal (consentimiento) — especialmente datos financieros.
/// - Apps fintech como Mercado Pago, Revolut, Nubank lo hacen exactamente
///   así desde 2024.
///
/// **Diseño**: Midnight Sage card con 3 puntos claros + 2 acciones:
///   - "Aceptar y continuar" → marca consent ✓, cierra sheet
///   - "Usar solo on-device" → activa onDeviceOnly + marca consent ✓
///     (el toggle queda visible en Settings)
struct AssistantConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var privacy: PrivacyManager

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    bullets
                    legalNote
                    Spacer(minLength: 24)
                    actions
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .interactiveDismissDisabled() // Apple Review: el user debe decidir
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkles")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.brandPrimary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Asistente IA")
                    .font(.mcSerifTitle)
                    .foregroundStyle(Color.textPrimary)
                Text("Antes de empezar, tu consentimiento")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }
            Spacer()
        }
        .padding(.top, 12)
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 16) {
            row(
                icon: "iphone",
                title: "En tu iPhone (siempre)",
                body: "El reconocimiento de voz y el OCR de recibos corren on-device con Apple Speech y Vision."
            )
            row(
                icon: "cloud",
                title: "Qué se envía a Anthropic (Claude)",
                body: "Para responderte enviamos a Anthropic: tus mensajes y transcripciones de voz, un resumen de tus finanzas (montos, categorías, saldos, metas) y las fotos de recibos que elijas escanear."
            )
            row(
                icon: "waveform",
                title: "Qué se envía a ElevenLabs",
                body: "Solo en el modo voz: el texto de la respuesta del asistente se envía a ElevenLabs para convertirlo en audio."
            )
            row(
                icon: "lock.shield.fill",
                title: "Qué NUNCA se envía",
                body: "Nunca enviamos tus emails, contraseñas ni números de tarjeta. Anthropic y ElevenLabs no entrenan modelos de IA con tus datos."
            )
        }
    }

    private var legalNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tus derechos")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            Text("Podés revocar el consentimiento o activar el modo solo on-device en cualquier momento desde Ajustes → Privacidad del Asistente IA.")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
            Link(destination: URL(string: "https://metacasa-app-cf592.web.app/privacy.html")!) {
                HStack(spacing: 4) {
                    Text("Leer la Política de Privacidad")
                    Image(systemName: "arrow.up.right")
                }
                .font(.mcCaption.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
            }
        }
        .padding(14)
        .background(Color.appSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.play(.success)
                privacy.assistantCloudConsent = true
                privacy.assistantOnDeviceOnly = false
                dismiss()
            } label: {
                Text("Aceptar y continuar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MCPrimaryButton())

            Button {
                Haptics.play(.selection)
                privacy.assistantCloudConsent = true
                privacy.assistantOnDeviceOnly = true
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "iphone")
                    Text("Usar solo on-device (más lento)")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(Color.textPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    /// `title`/`body` como `LocalizedStringKey`: con `String`, `Text` usa la sobrecarga
    /// `verbatim` y el texto no pasa por el catálogo. Es la pantalla de consentimiento de IA —
    /// tiene que estar en el idioma del usuario para que el consentimiento signifique algo.
    private func row(icon: String, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 32, height: 32)
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
