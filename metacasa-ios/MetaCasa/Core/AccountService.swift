import Foundation

actor AccountService {
    static let shared = AccountService()
    private init() {}

    /// Cuenta a usar cuando el alta NO tiene UI para elegirla: Siri, los App Intents, el
    /// asistente, los recibos y las notas de voz.
    ///
    /// Devuelve la última cuenta que el usuario eligió a mano en el formulario (la misma clave
    /// que usa `AddTransactionView`), y si no existe o está inactiva, la primera activa del hogar.
    /// Antes todos esos caminos mandaban `accountId: nil`, así que sus movimientos no movían
    /// ningún saldo — la cuenta quedaba clavada en su balance inicial.
    ///
    /// `nil` sólo si el hogar no tiene cuentas activas: ahí no hay nada razonable que elegir.
    func defaultAccountId(householdId: UUID) async -> UUID? {
        let lastUsed = UserDefaults.standard.string(forKey: "lastUsedAccountId") ?? ""
        let accounts = (try? await fetchAll(householdId: householdId)) ?? []
        let activas = accounts.filter(\.isActive)
        if let id = UUID(uuidString: lastUsed), activas.contains(where: { $0.id == id }) {
            return id
        }
        return activas.first?.id
    }

    /// Read-through cache (ítem 4.1). Ver `OfflineFallbackPolicy`: solo se
    /// sirve cache ante fallas de RED, nunca ante 401/4xx.
    func fetchAll(householdId: UUID, includingInactive: Bool = false) async throws -> [Account] {
        var q = PgQuery().eq("household_id", householdId)
        if !includingInactive {
            q = q.eq("is_active", true)
        }
        q = q.order("display_order")
        do {
            let rows: [Account] = try await SupabaseRPC.select(from: "accounts", query: q)
            Task.detached(priority: .utility) {
                await OfflineCache.shared.replace(accounts: rows, householdId: householdId)
            }
            OfflineStatus.reportFreshData()
            return rows
        } catch {
            guard OfflineFallbackPolicy.allowsCachedFallback(for: error),
                  let cached = await OfflineCache.shared.loadAccounts(
                      householdId: householdId, includingInactive: includingInactive
                  ),
                  !cached.items.isEmpty
            else { throw error }
            OfflineStatus.reportCachedData(syncedAt: cached.syncedAt)
            return cached.items
        }
    }

    /// Saldo corriente de cada cuenta activa, calculado SERVER-SIDE vía
    /// `public.account_balances(p_household)`.
    ///
    /// Reemplaza al cómputo en el device, que bajaba hasta 10.000 transacciones
    /// de 365 días por cada refresh del Home. Además es más EXACTO: el RPC suma
    /// todas las transacciones de la cuenta, no solo la ventana de un año.
    /// SECURITY INVOKER → RLS decide qué hogar puede leer el caller.
    func balances(householdId: UUID) async throws -> [UUID: Decimal] {
        struct Params: Encodable { let p_household: UUID }
        struct Row: Decodable {
            let account_id: UUID
            let balance: Decimal
        }
        let rows: [Row] = try await SupabaseRPC.call(
            "account_balances",
            params: Params(p_household: householdId)
        )
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.account_id, $0.balance) })
    }

    func create(
        userId: UUID,
        householdId: UUID,
        name: String,
        type: AccountType,
        currency: String,
        startingBalance: Decimal = 0,
        institution: String? = nil,
        icon: String? = nil,
        color: String? = nil
    ) async throws -> Account {
        struct Payload: Encodable {
            let household_id: UUID
            let name: String
            let type: String
            let currency: String
            let starting_balance: Decimal
            let institution: String?
            let icon: String?
            let color: String?
            let created_by: UUID
        }
        let payload = Payload(
            household_id: householdId,
            name: name,
            type: type.rawValue,
            currency: currency,
            starting_balance: startingBalance,
            institution: institution,
            icon: icon,
            color: color,
            created_by: userId
        )
        return try await SupabaseRPC.insert(into: "accounts", payload: payload)
    }

    func update(_ account: Account) async throws -> Account {
        struct Patch: Encodable {
            let name: String
            let type: String
            let currency: String
            let starting_balance: Decimal
            let institution: String?
            let icon: String?
            let color: String?
            let display_order: Int
            let is_active: Bool
            let notes: String?
        }
        let patch = Patch(
            name: account.name,
            type: account.type.rawValue,
            currency: account.currency,
            starting_balance: account.startingBalance,
            institution: account.institution,
            icon: account.icon,
            color: account.color,
            display_order: account.displayOrder,
            is_active: account.isActive,
            notes: account.notes
        )
        return try await SupabaseRPC.update(
            table: "accounts",
            payload: patch,
            query: PgQuery().eq("id", account.id)
        )
    }

    func archive(id: UUID) async throws {
        struct Patch: Encodable { let is_active: Bool }
        try await SupabaseRPC.updateVoid(
            table: "accounts",
            payload: Patch(is_active: false),
            query: PgQuery().eq("id", id)
        )
    }

    /// Actualiza el ownership (personal/shared/external) y opcionalmente el user
    /// propietario. Usado para configurar waterfall multi-persona.
    func updateOwnership(id: UUID, ownership: AccountOwnership, ownerUserId: UUID? = nil) async throws {
        struct Patch: Encodable {
            let ownership: String
            let owner_user_id: UUID?
        }
        try await SupabaseRPC.updateVoid(
            table: "accounts",
            payload: Patch(ownership: ownership.rawValue, owner_user_id: ownerUserId),
            query: PgQuery().eq("id", id)
        )
    }
}
