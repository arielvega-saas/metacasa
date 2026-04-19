import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showResetConfirm = false

    let onSwitchToSignup: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            MCTextField(title: "Email", text: $email, keyboard: .emailAddress)
            MCTextField(title: "Contraseña", text: $password, secure: true)

            if let msg = errorMessage {
                Text(msg)
                    .font(.mcCaption)
                    .foregroundStyle(Color.brandDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await submit() }
            } label: {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Ingresar")
                }
            }
            .buttonStyle(MCPrimaryButton())
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding(.top, 6)

            HStack(spacing: 20) {
                Button("¿Olvidaste la contraseña?") { showResetConfirm = true }
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
                Button("Crear cuenta", action: onSwitchToSignup)
                    .font(.mcCaption.weight(.bold))
                    .foregroundStyle(Color.brandPrimary)
            }
            .padding(.top, 4)
        }
        .confirmationDialog(
            "Enviar instrucciones de recuperación a \(email)?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Enviar") {
                Task { await resetPassword() }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await appState.signIn(email: email.lowercased().trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func resetPassword() async {
        guard !email.isEmpty else {
            errorMessage = "Ingresá tu email arriba primero"
            return
        }
        do {
            try await AuthManager.shared.resetPassword(email: email)
            errorMessage = "Te enviamos un email a \(email). Revisá tu bandeja."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
