import Foundation

/// Espejo de la tabla `public.categories` de Supabase.
/// Una fila por household_id con un blob jsonb que contiene categorías custom.
struct CategoriesBlob: Codable, Sendable {
    let householdId: UUID
    var data: CategoriesData
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case data
        case updatedAt = "updated_at"
    }
}

struct CategoriesData: Codable, Sendable, Hashable {
    var gastos: [CategoryItem]
    var ingresos: [CategoryItem]

    enum CodingKeys: String, CodingKey {
        case gastos = "GASTO"
        case ingresos = "INGRESO"
    }

    init(gastos: [CategoryItem] = [], ingresos: [CategoryItem] = []) {
        self.gastos = gastos
        self.ingresos = ingresos
    }
}

struct CategoryItem: Codable, Sendable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var emoji: String?
    var subcategories: [String]?

    init(name: String, emoji: String? = nil, subcategories: [String]? = nil) {
        self.name = name
        self.emoji = emoji
        self.subcategories = subcategories
    }
}
