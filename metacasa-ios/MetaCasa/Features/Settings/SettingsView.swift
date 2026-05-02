import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(PrivacyManager.self) private var privacy
    @Environment(OnboardingProgress.self) private var onboarding
    @State private var showSignOutConfirm = false
    @State private var showWelcomeTour = false

    var body: some View {
        List {
            Section("more.section.household") {
                if let current = currentHousehold {
                    HStack {
                        Text(current.name)
                        Spacer()
                        Text(current.defaultCurrency).foregroundStyle(.secondary)
                    }
                }

                if appState.households.count > 1 {
                    Picker(
                        "settings.changeHousehold",
                        selection: Binding(
                            get: { appState.currentHouseholdId ?? UUID() },
                            set: { appState.switchHousehold(to: $0) }
                        )
                    ) {
                        ForEach(appState.households) { h in
                            Text(h.name).tag(h.id)
                        }
                    }
                }
            }

            Section("settings.section.account") {
                if let email = appState.session?.email {
                    HStack {
                        Text("auth.field.email")
                        Spacer()
                        Text(email).foregroundStyle(.secondary)
                    }
                }
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Text("settings.signout")
                }
            }

            Section("settings.section.preferences") {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label {
                        Text("settings.appearance")
                    } icon: {
                        Image(systemName: "moon.stars")
                    }
                }
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label {
                        Text("settings.notifications")
                    } icon: {
                        Image(systemName: "bell.badge")
                    }
                }
                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    Label {
                        Text("settings.language")
                    } icon: {
                        Image(systemName: "globe")
                    }
                }
                NavigationLink {
                    FXRatesView()
                } label: {
                    Label {
                        Text("settings.fxRates")
                    } icon: {
                        Image(systemName: "dollarsign.arrow.circlepath")
                    }
                }
                @Bindable var privacy = privacy
                Toggle(isOn: $privacy.isEnabled) {
                    Label {
                        Text("settings.privacy")
                    } icon: {
                        Image(systemName: privacy.isEnabled ? "eye.slash.fill" : "eye.fill")
                    }
                }

                // Re-mostrar el tour y el checklist para usuarios que los
                // dismissearon o que quieren revisarlos.
                Button {
                    Haptics.play(.selection)
                    showWelcomeTour = true
                } label: {
                    Label {
                        Text("tour.replay")
                    } icon: {
                        Image(systemName: "play.circle")
                    }
                    .foregroundStyle(Color.textPrimary)
                }

                if onboarding.isDismissed {
                    Button {
                        Haptics.play(.success)
                        onboarding.resetDismissal()
                        Task { await onboarding.refresh(appState: appState) }
                    } label: {
                        Label {
                            Text("onboarding.restore")
                        } icon: {
                            Image(systemName: "checklist")
                        }
                        .foregroundStyle(Color.textPrimary)
                    }
                }
            }

            Section("settings.section.security") {
                HStack {
                    Text("settings.biometrics")
                    Spacer()
                    Text(BiometricAuth.isAvailable ? BiometricAuth.biometryLabel : String(localized: "settings.biometrics.unavailable"))
                        .foregroundStyle(.secondary)
                }
            }

            Section("settings.section.householdMgmt") {
                NavigationLink {
                    HouseholdSettingsView()
                } label: {
                    Label {
                        Text("more.edit_household")
                    } icon: {
                        Image(systemName: "house.fill")
                    }
                }
                NavigationLink {
                    HouseholdMembersView()
                } label: {
                    Label {
                        Text("more.members")
                    } icon: {
                        Image(systemName: "person.3.fill")
                    }
                }
                NavigationLink {
                    ManageCategoriesView()
                } label: {
                    Label {
                        Text("more.categories")
                    } icon: {
                        Image(systemName: "tag.fill")
                    }
                }
            }

            Section("settings.section.data") {
                NavigationLink {
                    BackupView()
                } label: {
                    Label {
                        Text("settings.backup")
                    } icon: {
                        Image(systemName: "externaldrive.badge.icloud")
                    }
                }
            }

            Section("settings.section.legal") {
                NavigationLink {
                    LegalView(kind: .privacy)
                } label: {
                    Label {
                        Text("settings.legal.privacy")
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                    }
                }
                NavigationLink {
                    LegalView(kind: .terms)
                } label: {
                    Label {
                        Text("settings.legal.terms")
                    } icon: {
                        Image(systemName: "doc.text.fill")
                    }
                }
            }

            Section("settings.section.app") {
                HStack {
                    Text("settings.version")
                    Spacer()
                    Text("\(Config.appVersion) (\(Config.buildNumber))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(Text("more.settings"))
        .confirmationDialog("settings.signoutConfirm", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("settings.signout", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showWelcomeTour) {
            WelcomeTourView()
        }
    }

    private var currentHousehold: Household? {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })
    }
}
