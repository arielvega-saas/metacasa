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
            Text("Home Finance")
                .font(.mcDisplay)
                .foregroundStyle(Color.textPrimary)
            Text("Gestioná las finanzas de tu hogar")
                .font(.mcBody)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}

// MARK: - Helper estilizado compartido por inputs

struct MCTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false
    var autocapitalize: TextInputAutocapitalization = .never

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
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
