import Foundation

actor HouseholdService {
    static let shared = HouseholdService()
    private init() {}

    func fetchMine() async throws -> [Household] {
        try await SupabaseRPC.select(
            from: "households",
            query: PgQuery().order("created_at", ascending: true)
        )
    }

    func fetchMembers(householdId: UUID) async throws -> [HouseholdMember] {
        try await SupabaseRPC.select(
            from: "household_members",
            query: PgQuery().eq("household_id", householdId)
        )
    }

    func create(accessToken: String, name: String, defaultCurrency: String = "USD", timezone: String = TimeZone.current.identifier) async throws -> Household {
        // RPC server-side que resuelve auth.uid() internamente + atomicidad.
        // accessToken viene del AppState.session (guardado al signIn).
        struct Params: Encodable {
            let p_name: String
            let p_currency: String
            let p_timezone: String
        }
        return try await SupabaseRPC.call(
            "create_household",
            params: Params(
                p_name: name,
                p_currency: defaultCurrency,
                p_timezone: timezone
            ),
            accessToken: accessToken
        )
    }

    func createInvitation(userId: UUID, householdId: UUID, email: String, role: MemberRole = .member) async throws -> HouseholdInvitation {
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
        return try await SupabaseRPC.insert(into: "household_invitations", payload: payload)
    }

    /// Acepta una invitación por token. Agrega al caller como miembro del hogar correspondiente.
    /// Requiere la RPC `accept_household_invitation(invite_token text)` en Supabase.
    func acceptInvitation(token: String) async throws -> UUID {
        struct Params: Encodable { let invite_token: String }
        return try await SupabaseRPC.call(
            "accept_household_invitation",
            params: Params(invite_token: token)
        )
    }

    func listInvitations(householdId: UUID, onlyPending: Bool = true) async throws -> [HouseholdInvitation] {
        var q = PgQuery().eq("household_id", householdId)
        if onlyPending {
            q = q.eq("status", "pending")
        }
        q = q.order("created_at", ascending: false)
        return try await SupabaseRPC.select(from: "household_invitations", query: q)
    }

    func revokeInvitation(id: UUID) async throws {
        struct Patch: Encodable { let status: String }
        try await SupabaseRPC.updateVoid(
            table: "household_invitations",
            payload: Patch(status: "revoked"),
            query: PgQuery().eq("id", id)
        )
    }

    func removeMember(householdId: UUID, userId: UUID) async throws {
        try await SupabaseRPC.delete(
            from: "household_members",
            query: PgQuery()
                .eq("household_id", householdId)
                .eq("user_id", userId)
        )
    }

    func updateMemberRole(householdId: UUID, userId: UUID, role: MemberRole) async throws {
        struct Patch: Encodable { let role: String }
        try await SupabaseRPC.updateVoid(
            table: "household_members",
            payload: Patch(role: role.rawValue),
            query: PgQuery()
                .eq("household_id", householdId)
                .eq("user_id", userId)
        )
    }

    func renameHousehold(id: UUID, name: String) async throws -> Household {
        struct Patch: Encodable { let name: String }
        return try await SupabaseRPC.update(
            table: "households",
            payload: Patch(name: name),
            query: PgQuery().eq("id", id)
        )
    }

    func updateCurrency(householdId: UUID, currency: String) async throws -> Household {
        struct Patch: Encodable { let default_currency: String }
        return try await SupabaseRPC.update(
            table: "households",
            payload: Patch(default_currency: currency.uppercased()),
            query: PgQuery().eq("id", householdId)
        )
    }

    /// Actualiza el jsonb de estrategia waterfall del hogar.
    func updateStrategy(householdId: UUID, strategy: HouseholdStrategy) async throws -> Household {
        struct Patch: Encodable { let strategy: HouseholdStrategy }
        return try await SupabaseRPC.update(
            table: "households",
            payload: Patch(strategy: strategy),
            query: PgQuery().eq("id", householdId)
        )
    }
}
