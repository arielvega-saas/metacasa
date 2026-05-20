import SwiftUI

/// Sheet de eliminación de cuenta — requerido por App Store Review
/// Guideline 5.1.1(v). Flow de dos pasos:
///   1. Pantalla explicativa con consecuencias.
///   2. Confirmación tipeando "ELIMINAR" para evitar borrados accidentales.
/// Tras éxito, el sheet se cierra y `AppState` queda sin sesión → la app
/// vuelve sola a la pantalla de login.
struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var step: Step = .explain
    @State private var confirmText: String = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private enum Step { case explain, confirm }
    private let requiredWord = "ELIMINAR"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    iconHeader
                    switch step {
                    case .explain: explainContent
                    case .confirm: confirmContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Eliminar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isDeleting)
                }
            }
            .alert("No se pudo eliminar la cuenta",
                   isPresented: Binding(get: { errorMessage != nil },
                                        set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var iconHeader: some View {
        ZStack {
            Circle()
                .fill(Color.brandDanger.opacity(0.18))
                .frame(width: 72, height: 72)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.brandDanger)
        }
        .padding(.top, 8)
    }

    // MARK: - Step 1: Explain

    private var explainContent: some View {
        VStack(spacing: 18) {
            Text("Esta acción es permanente")
                .font(.mcSerifTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("Si eliminás tu cuenta, vas a perder el acceso a:")
                .font(.mcBody)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                bullet("Tu perfil y datos de inicio de sesión.")
                bullet("Tu membresía en todos los hogares compartidos. Si sos el único miembro de un hogar, sus datos quedan inaccesibles.")
                bullet("El historial del Asistente IA guardado en tu cuenta.")
                bullet("Cualquier suscripción activa via App Store (gestionala desde Ajustes → Apple ID → Suscripciones).")
            }
            .padding(16)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("No vamos a poder recuperar tu cuenta una vez confirmes.")
                .font(.mcCaption)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)

            Button {
                Haptics.play(.warning)
                step = .confirm
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Continuar")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brandDanger)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button("Cancelar") { dismiss() }
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.textMuted)
                .padding(.vertical, 6)
        }
    }

    // MARK: - Step 2: Confirm

    private var confirmContent: some View {
        VStack(spacing: 18) {
            Text("Confirmación final")
                .font(.mcSerifTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("Para confirmar la eliminación, escribí la palabra **\(requiredWord)** abajo:")
                .font(.mcBody)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)

            TextField(requiredWord, text: $confirmText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.mcBody.weight(.bold).monospaced())
                .multilineTextAlignment(.center)
                .padding(14)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(confirmText == requiredWord ? Color.brandDanger : Color.appBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                Task { await performDelete() }
            } label: {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "trash.fill")
                    }
                    Text(isDeleting ? "Eliminando..." : "Eliminar cuenta permanentemente")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(confirmText == requiredWord ? Color.brandDanger : Color.brandDanger.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(confirmText != requiredWord || isDeleting)

            Button("Volver") {
                confirmText = ""
                step = .explain
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(Color.textMuted)
            .padding(.vertical, 6)
            .disabled(isDeleting)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.brandDanger.opacity(0.85))
                .font(.callout)
            Text(text)
                .font(.mcBody)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Action

    private func performDelete() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await appState.deleteAccount()
            Haptics.play(.success)
            dismiss()
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }
}
