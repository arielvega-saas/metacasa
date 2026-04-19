import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignOutConfirm = false

    var body: some View {
        List {
            Section("Hogar") {
                if let current = currentHousehold {
                    HStack {
                        Text(current.name)
                        Spacer()
                        Text(current.defaultCurrency).foregroundStyle(.secondary)
                    }
                }

                if appState.households.count > 1 {
                    Picker(
                        "Cambiar hogar",
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

            Section("Cuenta") {
                if let email = appState.session?.email {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(email).foregroundStyle(.secondary)
                    }
                }
                Button("Cerrar sesión", role: .destructive) {
                    showSignOutConfirm = true
                }
            }

            Section("Seguridad") {
                HStack {
                    Text("Biometría")
                    Spacer()
                    Text(BiometricAuth.isAvailable ? BiometricAuth.biometryLabel : "No disponible")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Gestión del hogar") {
                NavigationLink {
                    HouseholdSettingsView()
                } label: {
                    Label("Editar hogar", systemImage: "house.fill")
                }
                NavigationLink {
                    HouseholdMembersView()
                } label: {
                    Label("Miembros e invitaciones", systemImage: "person.3.fill")
                }
                NavigationLink {
                    ManageCategoriesView()
                } label: {
                    Label("Categorías", systemImage: "tag.fill")
                }
            }

            Section("App") {
                HStack {
                    Text("Versión")
                    Spacer()
                    Text("\(Config.appVersion) (\(Config.buildNumber))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Ajustes")
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var currentHousehold: Household? {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })
    }
}
