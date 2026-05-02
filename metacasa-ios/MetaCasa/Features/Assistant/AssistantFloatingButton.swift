import SwiftUI

/// Botón flotante global del asistente. Se overlaya en `RootView` cuando hay
/// sesión activa para ser accesible desde cualquier pantalla. Tap → abre
/// `AssistantChatView` como sheet.
struct AssistantFloatingButton: View {
    @State private var showChat = false

    var body: some View {
        Button {
            showChat = true
        } label: {
            ZStack {
                // Halo sage glow exterior — estética Midnight Sage
                Circle()
                    .fill(Color.brandPrimary.opacity(0.25))
                    .frame(width: 68, height: 68)
                    .blur(radius: 8)

                Circle()
                    .fill(Color.brandPrimary)                         // sage glow sólido
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .stroke(Color.brandSecondary.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.brandPrimary.opacity(0.35), radius: 10, x: 0, y: 4)

                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hex: "#0E1312"))           // dark text sobre sage
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("a11y.fab.openAssistant"))
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showChat) {
            AssistantChatView()
        }
    }
}
