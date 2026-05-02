import Foundation

/// Snapshot compacto del estado financiero, serializado a JSON y escrito en
/// un App Group UserDefaults compartido entre la app principal y la widget
/// extension.
///
/// **Setup necesario en Apple Developer Portal antes de habilitar este widget**:
/// 1. Crear App Group `group.com.metacasa.shared` en https://developer.apple.com/account/resources/identifiers/list/applicationGroup
/// 2. Agregarlo a tanto el bundle `com.metacasa.app` como `com.metacasa.app.widgets`.
/// 3. Descargar y regenerar los provisioning profiles.
/// 4. Agregar el App Group a ambos `.entitlements` files.
/// 5. Descomentar la línea `appGroupID` abajo y usar `UserDefaults(suiteName:)`.
///
/// Mientras tanto, en simulator con un solo target principal, este struct
/// igual compila — el Widget extension la agregaremos cuando tengamos Team
/// ID configurado.
public struct WidgetSnapshot: Codable, Sendable {
    public let householdName: String
    public let currency: String
    public let balanceMonth: String   // ya formateado (evita requerir Locale en widget)
    public let ingresosMonth: String
    public let gastosMonth: String
    public let nextBillTitle: String?
    public let nextBillAmount: String?
    public let nextBillInDays: Int?
    public let updatedAt: Date

    public init(
        householdName: String,
        currency: String,
        balanceMonth: String,
        ingresosMonth: String,
        gastosMonth: String,
        nextBillTitle: String?,
        nextBillAmount: String?,
        nextBillInDays: Int?,
        updatedAt: Date = Date()
    ) {
        self.householdName = householdName
        self.currency = currency
        self.balanceMonth = balanceMonth
        self.ingresosMonth = ingresosMonth
        self.gastosMonth = gastosMonth
        self.nextBillTitle = nextBillTitle
        self.nextBillAmount = nextBillAmount
        self.nextBillInDays = nextBillInDays
        self.updatedAt = updatedAt
    }

    // MARK: - Storage

    /// App Group identifier. Cambiá acá si usás otro nombre en el portal.
    public static let appGroupID = "group.com.metacasa.shared"

    /// UserDefaults key para el snapshot serializado.
    public static let storageKey = "widget_snapshot_v1"

    /// Escribe en el App Group. Si el App Group no está configurado (ej. en
    /// simulator sin entitlements), falla silenciosamente.
    public func persist() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    /// Lee el último snapshot del App Group. Retorna nil si no existe o falla.
    public static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
