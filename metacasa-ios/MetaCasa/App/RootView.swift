import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppLocaleManager.self) private var localeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showWelcomeTour = false
    /// Gate global del modelo trial-duro: 7 días gratis → app bloqueada hasta
    /// suscribirse. Ver `AccessController` / `TrialManager`.
    @State private var access = AccessController()

    var body: some View {
        Group {
            if appState.isBootstrapping {
                LaunchView()
            } else if appState.session == nil {
                AuthFlowView()
            } else if appState.currentHouseholdId == nil {
                CreateJoinHouseholdView()
            } else {
                // Trial-gate: la app entera vive detrás de esto. El gate va
                // DESPUÉS de auth+hogar para que "Restaurar compras" siga
                // siendo accesible cuando el trial venció.
                switch access.state {
                case .loading:
                    LaunchView()
                case .locked:
                    LockedPaywallView(onUnlock: { await access.refresh() })
                case .granted:
                    mainApp
                }
            }
        }
        .task { access.start() }
        .onChange(of: appState.currentUserId) { _, _ in
            Task { await access.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Re-evaluar al volver del background: el trial puede haber
            // vencido mientras la app estaba suspendida.
            if phase == .active {
                Task { await access.refresh() }
            }
        }
        // SwiftUI no refresca `navigationTitle` automáticamente cuando cambia
        // el environment locale a runtime. Forzamos rebuild completo del
        // subtree al cambiar idioma — el costo es perder navigation state
        // (tab actual, sheets abiertos), trade-off aceptable porque cambiar
        // idioma es raro y el reset es esperable para el usuario.
        .id(localeManager.current)
        .animation(.default, value: appState.session?.userId)
        .animation(.default, value: appState.currentHouseholdId)
        .animation(.default, value: access.state)
    }

    /// La app real (todos los tabs). Solo se muestra con acceso concedido
    /// (trial vigente o suscripción activa).
    private var mainApp: some View {
        MainTabView()
            .overlay(alignment: .bottomTrailing) {
                AssistantFloatingButton()
                    .padding(.trailing, 16)
                    // Padding bottom = tab bar (~49pt) + safe area inset (~34pt) + extra = ~100pt
                    // Deja el botón justo por encima del tab bar.
                    .padding(.bottom, 100)
            }
            // Welcome tour full-screen carousel — solo la primera vez
            // después de tener hogar. Persiste el dismiss para nunca
            // volver a mostrarlo (re-accesible desde Settings).
            .fullScreenCover(isPresented: $showWelcomeTour) {
                WelcomeTourView()
            }
            .task(id: appState.currentHouseholdId) {
                // Pequeño delay para no competir con la animación de entrada.
                try? await Task.sleep(nanoseconds: 600_000_000)
                if !WelcomeTourStorage.hasSeenTour {
                    showWelcomeTour = true
                }
            }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Image("LogoMetacasa")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                ProgressView().tint(.white)
            }
        }
    }
}
