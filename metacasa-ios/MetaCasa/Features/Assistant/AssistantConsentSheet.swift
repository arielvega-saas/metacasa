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
                body: "Reconocimiento de voz, OCR de recibos y análisis básico corren on-device con Apple Speech y Vision. No salen del dispositivo."
            )
            row(
                icon: "cloud",
                title: "En la nube (solo cuando hace falta)",
                body: "Las preguntas complejas se procesan con Claude (Anthropic). Enviamos tu pregunta + un resumen de tus datos (montos, categorías, fechas). Nunca emails, ni tarjetas, ni contraseñas."
            )
            row(
                icon: "lock.shield.fill",
                title: "Tu data no se usa para entrenar",
                body: "Anthropic NO entrena modelos con consultas de su API. Las conversaciones no se guardan en servidores nuestros más allá de tu propia sesión."
            )
        }
    }

    private var legalNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tus derechos")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            Text("Podés revocar el consentimiento o activar el modo solo on-device en cualquier momento desde Ajustes → Privacidad. Detalles en nuestra Política de Privacidad.")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
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

    private func row(icon: String, title: String, body: String) -> some View {
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
