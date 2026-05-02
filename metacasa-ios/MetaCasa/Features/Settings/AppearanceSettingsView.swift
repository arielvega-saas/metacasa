import SwiftUI

/// Picker de tema (Automático / Claro / Oscuro). Cumplir HIG requiere darle
/// al usuario la opción de seguir el sistema.
struct AppearanceSettingsView: View {
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        List {
            Section {
                @Bindable var appearance = appearance
                ForEach(AppearancePreference.allCases) { pref in
                    Button {
                        appearance.preference = pref
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: pref.systemIcon)
                                .font(.body)
                                .foregroundStyle(Color.brandPrimary)
                                .frame(width: 28)
                            Text(pref.labelKey)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if appearance.preference == pref {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("appearance.section.theme")
            } footer: {
                Text("appearance.footer")
            }
        }
        .navigationTitle(Text("appearance.title"))
    }
}
