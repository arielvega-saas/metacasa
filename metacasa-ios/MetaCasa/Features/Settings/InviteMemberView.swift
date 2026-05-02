import SwiftUI

/// Invitar un miembro al hogar. Crea un `HouseholdInvitation` con token único
/// y muestra un card para compartir el token vía copy (con feedback visual) o
/// ShareLink nativo (iMessage, WhatsApp, Mail, etc.).
struct InviteMemberView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var role: MemberRole = .member
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdInvite: HouseholdInvitation?
    @State private var justCopied = false

    let onSaved: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let invite = createdInvite {
                    successSection(invite: invite)
                } else {
                    inputSection
                }
            }
            .navigationTitle(Text("invite.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                if createdInvite == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isLoading ? String(localized: "invite.creating") : String(localized: "invite.create")) {
                            Task { await submit() }
                        }
                        .fontWeight(.semibold)
                        .disabled(isLoading || !email.contains("@"))
                    }
                }
            }
        }
    }

    // MARK: - Input

    @ViewBuilder
    private var inputSection: some View {
        Section {
            TextField("invite.emailPlaceholder", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("invite.inviteByEmail")
        } footer: {
            Text("invite.emailHint")
        }

        Section {
            Picker(selection: $role) {
                ForEach([MemberRole.admin, .member, .viewer], id: \.self) { r in
                    Text(roleKey(r)).tag(r)
                }
            } label: {
                Text("invite.role")
            }
            Text(roleHintKey(role))
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("invite.role")
        }

        if let msg = errorMessage {
            Section {
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.brandDanger)
                    .font(.caption)
            }
        }
    }

    // MARK: - Success

    @ViewBuilder
    private func successSection(invite: HouseholdInvitation) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandSuccess)
                    Text("invite.created").font(.mcH2)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("invite.shareWith \(invite.email)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(invite.inviteToken)
                        .font(.system(.callout, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.brandPrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .textSelection(.enabled)
                }

                Text("invite.expires \(invite.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Button {
                copyToken(invite.inviteToken)
            } label: {
                HStack {
                    Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .foregroundStyle(justCopied ? Color.brandSuccess : Color.brandPrimary)
                        .contentTransition(.symbolEffect)
                    Text(justCopied ? "invite.copied" : "invite.copy")
                        .fontWeight(.semibold)
                }
            }

            ShareLink(
                item: shareMessage(for: invite),
                subject: Text("invite.shareSubject"),
                message: Text("invite.shareMessageBody")
            ) {
                Label {
                    Text("invite.share")
                } icon: {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundStyle(Color.brandPrimary)
                }
            }
        }

        Section {
            Button {
                dismiss()
            } label: {
                Text("action.close")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Helpers

    private func copyToken(_ token: String) {
        UIPasteboard.general.string = token
        Haptics.play(.success)
        withAnimation(.easeOut(duration: 0.2)) {
            justCopied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation { justCopied = false }
            }
        }
    }

    private func shareMessage(for invite: HouseholdInvitation) -> String {
        String(
            format: String(localized: "invite.shareTemplate"),
            invite.inviteToken
        )
    }

    private func roleKey(_ r: MemberRole) -> LocalizedStringKey {
        switch r {
        case .owner:  return "role.owner"
        case .admin:  return "role.admin"
        case .member: return "role.member"
        case .viewer: return "role.viewer"
        }
    }

    private func roleHintKey(_ r: MemberRole) -> LocalizedStringKey {
        switch r {
        case .owner:  return "role.hint.owner"
        case .admin:  return "role.hint.admin"
        case .member: return "role.hint.member"
        case .viewer: return "role.hint.viewer"
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let hid = appState.currentHouseholdId else {
            errorMessage = String(localized: "error.household_missing"); return
        }
        isLoading = true
        defer { isLoading = false }
        guard let uid = appState.currentUserId else {
            errorMessage = String(localized: "error.session_missing")
            return
        }
        do {
            let inv = try await HouseholdService.shared.createInvitation(
                userId: uid, householdId: hid, email: email, role: role
            )
            createdInvite = inv
            Haptics.play(.success)
            await onSaved()
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }
}
