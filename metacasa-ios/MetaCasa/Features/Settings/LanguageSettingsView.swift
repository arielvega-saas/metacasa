import SwiftUI

/// Pantalla para que el usuario elija el idioma de la app.
/// Al seleccionar, `AppLocaleManager.shared.current` se actualiza, persiste en
/// `UserDefaults` y el cambio se propaga al environment `\.locale` del root.
struct LanguageSettingsView: View {
    @Environment(AppLocaleManager.self) private var localeManager

    var body: some View {
        List {
            Section {
                ForEach(SupportedLocale.allCases) { locale in
                    Button {
                        localeManager.current = locale
                    } label: {
                        HStack(spacing: 12) {
                            Text(locale.flag)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(locale.nativeLabel)
                                    .foregroundStyle(.primary)
                                if locale == .system {
                                    Text(Locale.autoupdatingCurrent.identifier)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if localeManager.current == locale {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("settings.language.hint")
            }
        }
        .navigationTitle(Text("settings.language"))
    }
}
