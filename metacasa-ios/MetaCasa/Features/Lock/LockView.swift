import SwiftUI

/// Pantalla de bloqueo biométrico (ítem 3.2). `RootView` la renderiza EN VEZ
/// del árbol de la app cuando hay sesión y `BiometricLockManager` está
/// bloqueado — la app real ni se construye mientras tanto.
///
/// Al aparecer intenta biometría automáticamente (una vez); si el user
/// cancela, queda el botón "Desbloquear" para reintentar.
struct LockView: View {
    @Environment(BiometricLockManager.self) private var lockManager
    @State private var isAuthenticating = false
    @State private var didAutoPrompt = false

    private var biometryIcon: String {
        switch BiometricAuth.biometryType {
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "faceid"
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image("LogoMetacasa")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                VStack(spacing: 8) {
                    Text("lock.title")
                        .font(.mcH2)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("lock.subtitle")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Button {
                    Haptics.play(.selection)
                    Task { await attemptUnlock() }
                } label: {
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color(hex: "#0E1312"))
                        } else {
                            Image(systemName: biometryIcon)
                        }
                        Text("lock.unlock")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MCPrimaryButton())
                .disabled(isAuthenticating)
                .padding(.horizontal, 48)

                Spacer()
                Spacer()
            }
        }
        .task {
            // Intento automático al aparecer — una sola vez por aparición.
            // El pequeño delay deja que la escena termine de activarse antes
            // de presentar el prompt del sistema (evita evaluaciones que se
            // cancelan solas durante la transición).
            guard !didAutoPrompt else { return }
            didAutoPrompt = true
            try? await Task.sleep(nanoseconds: 350_000_000)
            await attemptUnlock()
        }
    }

    private func attemptUnlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await lockManager.unlock() {
            Haptics.play(.success)
        }
    }
}
