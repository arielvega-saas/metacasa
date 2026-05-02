import SwiftUI
import Foundation

@main
struct MetaCasaApp: App {
    @State private var appState = AppState()
    @State private var localeManager = AppLocaleManager.shared
    @State private var appearance = AppearanceManager.shared
    @State private var privacy = PrivacyManager.shared
    @State private var notifPrefs = NotificationPreferences.shared
    @State private var dashboardPrefs = DashboardPreferences.shared
    @State private var onboarding = OnboardingProgress()

    init() {
        // Solo NSException handler — el `signal(SIGTRAP)` handler con `exit()`
        // observado interfería con operaciones normales.
        NSSetUncaughtExceptionHandler { exception in
            fputs("[crash] NSException: \(exception.name.rawValue)\n", stderr)
            fputs("[crash] reason: \(exception.reason ?? "nil")\n", stderr)
            for symbol in exception.callStackSymbols {
                fputs("[crash] \(symbol)\n", stderr)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(localeManager)
                .environment(appearance)
                .environment(privacy)
                .environment(notifPrefs)
                .environment(dashboardPrefs)
                .environment(onboarding)
                // Propaga el locale override al environment de SwiftUI.
                // Esto hace que Text(LocalizedStringKey), .formatted(), DatePicker,
                // etc. respeten el idioma elegido por el usuario sin tocar cada view.
                .environment(\.locale, localeManager.effectiveLocale)
                // Tema según preferencia del usuario. `.system` = nil → sigue al sistema.
                .preferredColorScheme(appearance.preference.colorScheme)
                .task {
                    await RevenueCatService.shared.configure()
                    await appState.bootstrap()
                    if let uid = appState.currentUserId {
                        await RevenueCatService.shared.login(userId: uid)
                    }
                    // Donamos App Intents al sistema para que aparezcan en
                    // sugerencias de Siri/Spotlight y en Lock Screen widgets
                    // basados en el patrón de uso del user.
                    await IntentDonations.donateAll()
                }
                .onChange(of: appState.currentUserId) { _, newUid in
                    Task { @MainActor in
                        if let uid = newUid {
                            await RevenueCatService.shared.login(userId: uid)
                        } else {
                            await RevenueCatService.shared.logout()
                        }
                    }
                }
        }
    }
}
