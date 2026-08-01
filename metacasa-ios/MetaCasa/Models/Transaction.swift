import Foundation

struct Transaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var userId: UUID
    var accountId: UUID?
    var type: TxType
    var amount: Decimal
    var amountOriginal: Decimal?
    var currencyOriginal: String?
    var fxRateToBase: Decimal?
    var fxSource: String?
    var fxStatus: String?
    var category: String
    var subcategory: String?
    var account: String?
    var note: String?
    var date: Date
    var periodYear: Int?
    var periodMonth: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case userId = "user_id"
        case accountId = "account_id"
        case type
        case amount
        case amountOriginal = "amount_original"
        case currencyOriginal = "currency_original"
        case fxRateToBase = "fx_rate_to_base"
        case fxSource = "fx_source"
        case fxStatus = "fx_status"
        case category
        case subcategory
        case account
        case note
        case date
        case periodYear = "period_year"
        case periodMonth = "period_month"
        case createdAt = "created_at"
    }
}

enum TxType: String, Codable, Hashable, Sendable, CaseIterable {
    case gasto = "GASTO"
    case ingreso = "INGRESO"

    var label: String {
        switch self {
        case .gasto: "Gasto"
        case .ingreso: "Ingreso"
        }
    }

    var systemIcon: String {
        switch self {
        case .gasto: "arrow.down.circle.fill"
        case .ingreso: "arrow.up.circle.fill"
        }
    }
}

/// Payload para insertar una tx nueva. Supabase completará id/created_at.
struct NewTransactionInput: Codable, Sendable {
    var householdId: UUID
    var userId: UUID
    var accountId: UUID?
    var type: TxType
    /// **Siempre en la moneda BASE del hogar.** Es el contrato canónico, escrito en
    /// `metacasa-web/AGENTS_CONTRACT.md`: todos los agregados (totales del Home,
    /// `envelope_balance`, el matview mensual) asumen que esta columna está en base.
    var amount: Decimal
    /// Monto tal como lo tipeó el usuario, en `currencyOriginal`.
    ///
    /// Faltaba, y por eso el original se perdía para siempre: iOS guardaba el monto ya convertido
    /// pero lo etiquetaba con la moneda extranjera. Un gasto de USD 100 en un hogar ARS a 1500 se
    /// guardaba como 150000 con `currency_original = "USD"`, y la lista mostraba "US$ 150.000".
    var amountOriginal: Decimal?
    var currencyOriginal: String?
    /// Cuántas unidades de la moneda base equivalen a 1 de `currencyOriginal`.
    /// Vale 1 cuando no hubo conversión. Invariante: `amount == amountOriginal * fxRateToBase`.
    var fxRateToBase: Decimal?
    var category: String
    var subcategory: String?
    var note: String?

    /// Fecha del movimiento, **siempre normalizada a mediodía UTC** por el init.
    ///
    /// El `private(set)` y el init son a propósito: la normalización tiene que ser imposible de
    /// saltear. Hay 8 caminos que crean transacciones (alta manual, import CSV, dos App Intents,
    /// asistente, recibos, voz, tool de IA) y parchear cada uno dejaba la puerta abierta al noveno.
    /// Poniéndolo acá, el que agregue un camino nuevo lo hereda sin enterarse.
    private(set) var date: Date

    init(
        householdId: UUID,
        userId: UUID,
        accountId: UUID?,
        type: TxType,
        amount: Decimal,
        amountOriginal: Decimal? = nil,
        currencyOriginal: String?,
        fxRateToBase: Decimal? = nil,
        category: String,
        subcategory: String?,
        note: String?,
        date: Date
    ) {
        self.householdId = householdId
        self.userId = userId
        self.accountId = accountId
        self.type = type
        self.amount = amount
        self.amountOriginal = amountOriginal
        self.currencyOriginal = currencyOriginal
        self.fxRateToBase = fxRateToBase
        self.category = category
        self.subcategory = subcategory
        self.note = note
        self.date = date.stableForStorage()
    }

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case userId = "user_id"
        case accountId = "account_id"
        case type
        case amount
        case amountOriginal = "amount_original"
        case currencyOriginal = "currency_original"
        case fxRateToBase = "fx_rate_to_base"
        case category
        case subcategory
        case note
        case date
    }
}
