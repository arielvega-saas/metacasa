import SwiftUI

/// Configuración de notificaciones locales. Muestra el estado actual de
/// autorización + toggles por tipo. Si el sistema está en `denied`, muestra
/// botón "Abrir Ajustes de iOS" para que el user destrabe.
struct NotificationSettingsView: View {
    @Environment(NotificationPreferences.self) private var prefs
    @State private var authState: NotificationService.AuthorizationState = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        List {
            Section {
                authStatusRow
                if authState == .notDetermined {
                    Button {
                        Task { await requestPermission() }
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView().tint(.primary)
                            } else {
                                Image(systemName: "bell.badge.fill")
                            }
                            Text("notif.permit")
                        }
                    }
                    .disabled(isRequesting)
                } else if authState == .denied {
                    Button {
                        openSystemSettings()
                    } label: {
                        Label {
                            Text("notif.openIOSSettings")
                        } icon: {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            } header: {
                Text("notif.section.systemPermission")
            } footer: {
                Text(authFooterKey)
            }

            if authState == .authorized || authState == .provisional {
                Section {
                    @Bindable var prefs = prefs
                    Toggle(isOn: $prefs.bills) {
                        Label {
                            Text("notif.toggle.bills")
                        } icon: {
                            Image(systemName: "calendar.badge.exclamationmark")
                        }
                    }
                    Toggle(isOn: $prefs.goals) {
                        Label {
                            Text("notif.toggle.goals")
                        } icon: {
                            Image(systemName: "target")
                        }
                    }
                    Toggle(isOn: $prefs.recurring) {
                        Label {
                            Text("notif.toggle.recurring")
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                } header: {
                    Text("notif.section.what")
                } footer: {
                    Text("notif.footer.what")
                }

                if prefs.bills {
                    Section {
                        @Bindable var prefs = prefs
                        Stepper(value: $prefs.billsDaysBefore, in: 1...7) {
                            HStack {
                                Text("notif.bills.daysBefore")
                                Spacer()
                                Text("notif.bills.daysBeforeValue \(prefs.billsDaysBefore)")
                                    .foregroundStyle(Color.brandPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                        Stepper(value: $prefs.billsHour, in: 6...22) {
                            HStack {
                                Text("notif.bills.hour")
                                Spacer()
                                Text(String(format: "%02d:00", prefs.billsHour))
                                    .foregroundStyle(Color.brandPrimary)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                        }
                    } header: {
                        Text("notif.bills.timing")
                    } footer: {
                        Text("notif.bills.timingHint \(prefs.billsDaysBefore) \(String(format: "%02d:00", prefs.billsHour))")
                    }
                }

                if prefs.goals {
                    Section {
                        @Bindable var prefs = prefs
                        Stepper(value: $prefs.goalsMonthlyDay, in: 1...28) {
                            HStack {
                                Text("notif.goals.dayOfMonth")
                                Spacer()
                                Text("notif.goals.dayOfMonthValue \(prefs.goalsMonthlyDay)")
                                    .foregroundStyle(Color.brandPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                    } header: {
                        Text("notif.goals.timing")
                    } footer: {
                        Text("notif.goals.timingHint \(prefs.goalsMonthlyDay)")
                    }
                }
            }
        }
        .navigationTitle(Text("notif.title"))
        .task { await refresh() }
    }

    private var authStatusRow: some View {
        HStack {
            Label {
                Text("notif.status.label")
            } icon: {
                Image(systemName: authState == .authorized ? "checkmark.seal.fill" : "exclamationmark.shield")
            }
            Spacer()
            Text(authLabelKey)
                .font(.caption.weight(.semibold))
                .foregroundStyle(authColor)
        }
    }

    private var authLabelKey: LocalizedStringKey {
        switch authState {
        case .notDetermined: "notif.status.notDetermined"
        case .denied: "notif.status.denied"
        case .authorized: "notif.status.authorized"
        case .provisional: "notif.status.provisional"
        case .ephemeral: "notif.status.ephemeral"
        }
    }

    private var authColor: Color {
        switch authState {
        case .authorized, .provisional: .brandSuccess
        case .denied: .brandDanger
        default: .brandWarning
        }
    }

    private var authFooterKey: LocalizedStringKey {
        switch authState {
        case .notDetermined: "notif.footer.notDetermined"
        case .denied: "notif.footer.denied"
        case .authorized, .provisional, .ephemeral: "notif.footer.authorized"
        }
    }

    @MainActor
    private func refresh() async {
        authState = await NotificationService.shared.authorizationState()
    }

    @MainActor
    private func requestPermission() async {
        isRequesting = true
        defer { isRequesting = false }
        _ = await NotificationService.shared.requestAuthorization()
        await refresh()
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
