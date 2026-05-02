import SwiftUI

struct AuthFlowView: View {
    @State private var mode: Mode = .login
    enum Mode { case login, signup }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        Spacer(minLength: 32)
                        Group {
                            switch mode {
                            case .login:  LoginView(onSwitchToSignup: { mode = .signup })
                            case .signup: SignupView(onSwitchToLogin: { mode = .login })
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .animation(.default, value: mode)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            Image("LogoMetacasa")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Text("auth.login.title")
                .font(.mcDisplay)
                .foregroundStyle(Color.textPrimary)
            Text("auth.login.subtitle")
                .font(.mcBody)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}

// MARK: - Helpers estilizados compartidos por inputs

struct MCTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false
    var autocapitalize: TextInputAutocapitalization = .never

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .textCase(.uppercase)
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(autocapitalize)
                        .autocorrectionDisabled(true)
                }
            }
            .font(.mcBody)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

/// Campo de contraseña con ojito para mostrar/ocultar.
/// Conserva el foco y el cursor al alternar.
struct MCPasswordField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    @State private var isRevealed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .textCase(.uppercase)
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            HStack(spacing: 8) {
                Group {
                    if isRevealed {
                        TextField("", text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($focused)
                    } else {
                        SecureField("", text: $text)
                            .textContentType(.password)
                            .focused($focused)
                    }
                }
                .font(.mcBody)
                .foregroundStyle(Color.textPrimary)

                Button {
                    isRevealed.toggle()
                    // Mantener foco al alternar
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        focused = true
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(isRevealed ? "Ocultar contraseña" : "Mostrar contraseña")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
