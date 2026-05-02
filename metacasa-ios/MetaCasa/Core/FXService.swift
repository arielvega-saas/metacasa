import Foundation

/// Tasa de cambio manual — "cuántas unidades de la moneda BASE del hogar
/// equivalen a 1 unidad de esta moneda". Ej: hogar en ARS, USD rate 1000 →
/// 1 USD = 1000 ARS.
struct FXRate: Codable, Hashable, Sendable {
    var rate: Decimal
    /// ISO 8601 — cuándo el usuario actualizó el rate.
    var updatedAt: String
    /// "manual" por ahora; dejamos el campo para auto-fetch futuro (Open Exchange Rates).
    var source: String

    enum CodingKeys: String, CodingKey {
        case rate
        case updatedAt = "updated_at"
        case source
    }
}

/// Mapa de tasas FX del hogar. Clave = código de moneda ISO (USD, EUR, BRL, …).
/// Codable para poder ida y vuelta a jsonb en Supabase.
typealias FXRateMap = [String: FXRate]

/// Servicio para leer/escribir tasas manuales de FX.
/// Las guardamos en `households.fx_rates` (jsonb) — no hay tabla dedicada.
actor FXService {
    static let shared = FXService()
    private init() {}

    /// Descarga las tasas del hogar.
    func fetch(householdId: UUID) async throws -> FXRateMap {
        struct Row: Decodable { let fx_rates: FXRateMap? }
        let rows: [Row] = try await SupabaseRPC.select(
            from: "households",
            query: PgQuery(select: "fx_rates").eq("id", householdId)
        )
        return rows.first?.fx_rates ?? [:]
    }

    /// Actualiza el mapa completo de tasas (reemplaza el jsonb entero).
    func save(householdId: UUID, rates: FXRateMap) async throws {
        struct Patch: Encodable { let fx_rates: FXRateMap }
        try await SupabaseRPC.updateVoid(
            table: "households",
            payload: Patch(fx_rates: rates),
            query: PgQuery().eq("id", householdId)
        )
    }

    /// Helper para fijar o actualizar una tasa puntual.
    func setRate(householdId: UUID, currency: String, rate: Decimal) async throws {
        var current = try await fetch(householdId: householdId)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        current[currency.uppercased()] = FXRate(
            rate: rate,
            updatedAt: iso.string(from: Date()),
            source: "manual"
        )
        try await save(householdId: householdId, rates: current)
    }

    func removeRate(householdId: UUID, currency: String) async throws {
        var current = try await fetch(householdId: householdId)
        current.removeValue(forKey: currency.uppercased())
        try await save(householdId: householdId, rates: current)
    }
}

/// Utilities de conversión usando el mapa de FX.
enum FXConverter {
    /// Convierte `amount` desde `from` a `base` usando el mapa del hogar.
    /// Si `from == base` devuelve el monto tal cual.
    /// Si no hay tasa disponible, devuelve nil.
    static func convert(_ amount: Decimal, from: String, to base: String, rates: FXRateMap) -> Decimal? {
        let from = from.uppercased()
        let base = base.uppercased()
        if from == base { return amount }
        guard let r = rates[from] else { return nil }
        return amount * r.rate
    }
}
