import SwiftUI

@main
struct MetaCasaApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}
