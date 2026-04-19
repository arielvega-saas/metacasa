import SwiftUI

struct InviteMemberView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var role: MemberRole = .member
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdInvite: HouseholdInvitation?

    let onSaved: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let invite = createdInvite {
                    Section("Invitación creada") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compartí este token con \(invite.email):")
                                .font(.mcCaption)
                            Text(invite.inviteToken)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                            Text("Expira \(invite.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.mcCaption).foregroundStyle(.secondary)
                        }
                        Button("Copiar token") {
                            UIPasteboard.general.string = invite.inviteToken
                        }
                    }
                    Section {
                        Button("Cerrar") { dismiss() }
                    }
                } else {
                    Section("Invitar por email") {
                        TextField("persona@ejemplo.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Section("Rol") {
                        Picker("Rol", selection: $role) {
                            ForEach([MemberRole.admin, .member, .viewer], id: \.self) {
                                Text($0.label).tag($0)
                            }
                        }
                        Text(roleHint)
                            .font(.mcCaption)
                            .foregroundStyle(.secondary)
                    }
                    if let msg = errorMessage {
                        Section { Text(msg).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle("Invitar al hogar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                if createdInvite == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isLoading ? "Creando..." : "Crear invite") {
                            Task { await submit() }
                        }
                        .disabled(isLoading || !email.contains("@"))
                    }
                }
            }
        }
    }

    private var roleHint: String {
        switch role {
        case .owner:  return "Solo puede existir un propietario."
        case .admin:  return "Puede invitar, quitar miembros y editar el hogar."
        case .member: return "Puede registrar movimientos y editar presupuestos."
        case .viewer: return "Solo puede ver datos, no modificar."
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let hid = appState.currentHouseholdId else {
            errorMessage = "Hogar no disponible"; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let inv = try await HouseholdService.shared.createInvitation(
                householdId: hid, email: email, role: role
            )
            createdInvite = inv
            await onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
