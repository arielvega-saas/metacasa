import Foundation

actor CategoryService {
    static let shared = CategoryService()
    private init() {}

    /// Trae el blob de categorías custom del hogar.
    /// Si todavía no existe, devuelve nil (el cliente debe mergear con los defaults).
    func fetch(householdId: UUID) async throws -> CategoriesBlob? {
        try await SupabaseRPC.selectFirst(
            from: "categories",
            query: PgQuery().eq("household_id", householdId)
        )
    }

    /// Upsert del blob. PK es household_id.
    @discardableResult
    func save(householdId: UUID, data: CategoriesData) async throws -> CategoriesBlob {
        struct Payload: Encodable {
            let household_id: UUID
            let data: CategoriesData
        }
        return try await SupabaseRPC.upsert(
            into: "categories",
            payload: Payload(household_id: householdId, data: data),
            onConflict: "household_id"
        )
    }

    /// Combina defaults + custom. Si hay coincidencia de nombre, gana la custom (permite
    /// sobreescribir emoji o subcategorías).
    static func merged(custom: CategoriesData?, type: TxType) -> [CategoryItem] {
        let defaults: [String] = type == .gasto
            ? CategoryCatalog.defaultGastos
            : CategoryCatalog.defaultIngresos
        let defaultItems = defaults.map { name in
            CategoryItem(name: name, emoji: CategoryCatalog.emoji(for: name))
        }

        let customItems = type == .gasto
            ? (custom?.gastos ?? [])
            : (custom?.ingresos ?? [])

        let byName = Dictionary(uniqueKeysWithValues: defaultItems.map { ($0.name, $0) })
        let customByName = Dictionary(uniqueKeysWithValues: customItems.map { ($0.name, $0) })

        // Union preservando orden: primero defaults, luego custom nuevos
        var result: [CategoryItem] = []
        for item in defaultItems {
            result.append(customByName[item.name] ?? item)
        }
        for item in customItems where byName[item.name] == nil {
            result.append(item)
        }
        return result
    }
}
