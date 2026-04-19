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
    /// Requiere una RPC `accept_household_invitation(token text)` en Supabase (pendiente de implementar).
    func acceptInvitation(token: String) async throws -> UUID {
        struct Params: Encodable { let invite_token: String }
        let householdId: UUID = try await client
            .rpc("accept_household_invitation", params: Params(invite_token: token))
            .execute()
            .value
        return householdId
    }
}
