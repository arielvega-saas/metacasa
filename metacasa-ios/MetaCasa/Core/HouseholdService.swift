import Foundation
import Supabase

actor HouseholdService {
    static let shared = HouseholdService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.client }

    func fetchMine() async throws -> [Household] {
        try await client
            .from("households")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchMembers(householdId: UUID) async throws -> [HouseholdMember] {
        try await client
            .from("household_members")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value
    }

    func create(name: String, defaultCurrency: String = "USD", timezone: String = TimeZone.current.identifier) async throws -> Household {
        let userId = try await client.auth.session.user.id

        struct HouseholdPayload: Encodable {
            let name: String
            let default_currency: String
            let timezone: String
            let created_by: UUID
        }
        let payload = HouseholdPayload(
            name: name,
            default_currency: defaultCurrency,
            timezone: timezone,
            created_by: userId
        )

        let household: Household = try await client
            .from("households")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        // Agregar al creator como owner
        struct MemberPayload: Encodable {
            let household_id: UUID
            let user_id: UUID
            let role: String
        }
        try await client
            .from("household_members")
            .insert(MemberPayload(
                household_id: household.id,
                user_id: userId,
                role: "owner"
            ))
            .execute()

        return household
    }

    func createInvitation(householdId: UUID, email: String, role: MemberRole = .member) async throws -> HouseholdInvitation {
        let userId = try await client.auth.session.user.id

        struct Payload: Encodable {
            let household_id: UUID
            let email: String
            let role: String
            let invited_by: UUID
        }
        let payload = Payload(
            household_id: householdId,
            email: email,
            role: role.rawValue,
            invited_by: userId
        )
        return try await client
            .from("household_invitations")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Acepta una invitación por token. Agrega al caller como miembro del hogar correspondiente.
    /// Requiere la RPC `accept_household_invitation(invite_token text)` en Supabase (creada en migration 20260419121100).
    func acceptInvitation(token: String) async throws -> UUID {
        struct Params: Encodable { let invite_token: String }
        let householdId: UUID = try await client
            .rpc("accept_household_invitation", params: Params(invite_token: token))
            .execute()
            .value
        return householdId
    }

    func listInvitations(householdId: UUID, onlyPending: Bool = true) async throws -> [HouseholdInvitation] {
        var q = client
            .from("household_invitations")
            .select()
            .eq("household_id", value: householdId)

        if onlyPending {
            q = q.eq("status", value: "pending")
        }

        return try await q
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func revokeInvitation(id: UUID) async throws {
        struct Patch: Encodable { let status: String }
        try await client
            .from("household_invitations")
            .update(Patch(status: "revoked"))
            .eq("id", value: id)
            .execute()
    }

    func removeMember(householdId: UUID, userId: UUID) async throws {
        try await client
            .from("household_members")
            .delete()
            .eq("household_id", value: householdId)
            .eq("user_id", value: userId)
            .execute()
    }

    func updateMemberRole(householdId: UUID, userId: UUID, role: MemberRole) async throws {
        struct Patch: Encodable { let role: String }
        try await client
            .from("household_members")
            .update(Patch(role: role.rawValue))
            .eq("household_id", value: householdId)
            .eq("user_id", value: userId)
            .execute()
    }

    func renameHousehold(id: UUID, name: String) async throws -> Household {
        struct Patch: Encodable { let name: String }
        return try await client
            .from("households")
            .update(Patch(name: name))
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    func updateCurrency(householdId: UUID, currency: String) async throws -> Household {
        struct Patch: Encodable { let default_currency: String }
        return try await client
            .from("households")
            .update(Patch(default_currency: currency.uppercased()))
            .eq("id", value: householdId)
            .select()
            .single()
            .execute()
            .value
    }
}
