import SwiftUI
import Observation

@MainActor
@Observable
final class HouseholdMembersViewModel {
    var members: [HouseholdMember] = []
    var invitations: [HouseholdInvitation] = []
    var isLoading = false
    var errorMessage: String?

    func load(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let m = HouseholdService.shared.fetchMembers(householdId: householdId)
            async let i = HouseholdService.shared.listInvitations(householdId: householdId)
            self.members = try await m
            self.invitations = try await i
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HouseholdMembersView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HouseholdMembersViewModel()
    @State private var showInvite = false
    @State private var selectedMemberId: UUID?
    @State private var showRemoveConfirm = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            List {
                Section("Miembros (\(viewModel.members.count))") {
                    ForEach(viewModel.members, id: \.userId) { m in
                        memberRow(m)
                    }
                }
                if !viewModel.invitations.isEmpty {
                    Section("Invitaciones pendientes") {
                        ForEach(viewModel.invitations) { inv in
                            inviteRow(inv)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)

            if let msg = viewModel.errorMessage {
                VStack { Spacer(); Text(msg).foregroundStyle(.red).padding() }
            }
        }
        .navigationTitle(Text("Hogar"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInvite = true } label: { Image(systemName: "person.badge.plus") }
                    .disabled(!canInvite)
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteMemberView { await reload() }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .confirmationDialog("¿Quitar miembro?", isPresented: $showRemoveConfirm) {
            Button("Quitar", role: .destructive) {
                if let uid = selectedMemberId {
                    Task { await remove(userId: uid) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var canInvite: Bool {
        guard let hid = appState.currentHouseholdId,
              let me = viewModel.members.first(where: { $0.userId == appState.currentUserId })
        else { return false }
        _ = hid
        return me.role.canInvite
    }

    private func memberRow(_ m: HouseholdMember) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(Color.brandPrimary)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.displayName ?? "Miembro")
                    .font(.mcBody.weight(.bold))
                Text(m.role.label)
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }
            Spacer()
            if m.userId == appState.currentUserId {
                Text("Vos").font(.mcCaption).foregroundStyle(Color.brandPrimary)
            } else if canInvite {
                Button {
                    selectedMemberId = m.userId
                    showRemoveConfirm = true
                } label: {
                    Image(systemName: "xmark.circle").foregroundStyle(.red)
                }
            }
        }
    }

    private func inviteRow(_ inv: HouseholdInvitation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .foregroundStyle(Color.brandWarning)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(inv.email).font(.mcBody.weight(.semibold))
                Text("rol: \(inv.role.label) · expira \(inv.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.mcCaption).foregroundStyle(Color.textMuted)
            }
            Spacer()
            if canInvite {
                Button(role: .destructive) {
                    Task { await revoke(inv.id) }
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    @MainActor
    private func reload() async {
        if let hid = appState.currentHouseholdId {
            await viewModel.load(householdId: hid)
        }
    }

    @MainActor
    private func remove(userId: UUID) async {
        guard let hid = appState.currentHouseholdId else { return }
        do {
            try await HouseholdService.shared.removeMember(householdId: hid, userId: userId)
            await reload()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func revoke(_ id: UUID) async {
        do {
            try await HouseholdService.shared.revokeInvitation(id: id)
            await reload()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
