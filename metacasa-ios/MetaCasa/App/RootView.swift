import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isBootstrapping {
                LaunchView()
            } else if appState.session == nil {
                AuthFlowView()
            } else if appState.currentHouseholdId == nil {
                CreateJoinHouseholdView()
            } else {
                MainTabView()
            }
        }
        .animation(.default, value: appState.session?.userId)
        .animation(.default, value: appState.currentHouseholdId)
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
