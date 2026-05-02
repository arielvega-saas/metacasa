import SwiftUI

struct SignupView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    let onSwitchToLogin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            MCTextField(title: "Email", text: $email, keyboard: .emailAddress)
            MCPasswordField(title: "Contraseña (mínimo 8)", text: $password)
            MCPasswordField(title: "Confirmá contraseña", text: $confirmPassword)

            if let msg = errorMessage {
                Text(msg).font(.mcCaption).foregroundStyle(Color.brandDanger)
            }
            if let msg = successMessage {
                Text(msg).font(.mcCaption).foregroundStyle(Color.brandSuccess)
            }

            Button {
                Task { await submit() }
            } label: {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Crear cuenta")
                }
            }
            .buttonStyle(MCPrimaryButton())
            .disabled(isLoading || !isValid)
            .padding(.top, 6)

            Button("Ya tengo cuenta · Ingresar", action: onSwitchToLogin)
                .font(.mcCaption.weight(.bold))
                .foregroundStyle(Color.brandPrimary)
                .padding(.top, 4)

            Text("Al registrarte aceptás nuestros Términos y Política de Privacidad.")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private var isValid: Bool {
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await appState.signUp(email: email.lowercased().trimmingCharacters(in: .whitespaces), password: password)
        } catch let e as AuthError where e == .emailConfirmationPending {
            successMessage = "Te enviamos un email a \(email). Confirmalo para ingresar."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
