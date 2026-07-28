import Foundation
import SwiftData
import os

// MARK: - Modelos cacheados
//
// Cache OFFLINE consultable de las entidades que la UI lee más (ítem 4.1).
// No reemplaza a `HomeSnapshotStore` — ese guarda una FOTO de la pantalla Home
// para el cold start; esto es un espejo local de las filas de Supabase que los
// services pueden consultar cuando la red falla.
//
// ⚠️ REGLA DEL PROYECTO (lección del harness `leccion-swiftdata-migracion-default`):
// **toda** propiedad de un `@Model` lleva valor por defecto EN LA DECLARACIÓN.
// Una propiedad nueva sin default rompe los stores ya existentes en devices de
// usuarios reales, y los tests con store limpio no lo detectan.
//
// Los enums (`type`, `status`, `ownership`) se guardan como `String` crudo: si
// mañana el backend agrega un caso nuevo, un raw desconocido degrada a un
// default razonable en vez de fallar el decode de toda la lista.

@Model
final class CachedTransaction {
    var id: UUID = UUID()
    var householdId: UUID = UUID()
    var userId: UUID = UUID()
    var accountId: UUID?
    var typeRaw: String = TxType.gasto.rawValue
    var amount: Decimal = Decimal(0)
    var amountOriginal: Decimal?
    var currencyOriginal: String?
    var fxRateToBase: Decimal?
    var fxSource: String?
    var fxStatus: String?
    var category: String = ""
    var subcategory: String?
    /// Mapea a `Transaction.account` (nombre libre de la cuenta). Se renombra
    /// para no confundirse con el modelo `Account`.
    var accountLabel: String?
    var note: String?
    var date: Date = Date.distantPast
    var periodYear: Int?
    var periodMonth: Int?
    var createdAt: Date?
    /// Momento del último fetch de red exitoso que escribió esta fila.
    var syncedAt: Date = Date.distantPast

    init(_ tx: Transaction, syncedAt: Date) {
        self.id = tx.id
        self.householdId = tx.householdId
        self.userId = tx.userId
        self.accountId = tx.accountId
        self.typeRaw = tx.type.rawValue
        self.amount = tx.amount
        self.amountOriginal = tx.amountOriginal
        self.currencyOriginal = tx.currencyOriginal
        self.fxRateToBase = tx.fxRateToBase
        self.fxSource = tx.fxSource
        self.fxStatus = tx.fxStatus
        self.category = tx.category
        self.subcategory = tx.subcategory
        self.accountLabel = tx.account
        self.note = tx.note
        self.date = tx.date
        self.periodYear = tx.periodYear
        self.periodMonth = tx.periodMonth
        self.createdAt = tx.createdAt
        self.syncedAt = syncedAt
    }

    func toDomain() -> Transaction {
        Transaction(
            id: id,
            householdId: householdId,
            userId: userId,
            accountId: accountId,
            type: TxType(rawValue: typeRaw) ?? .gasto,
            amount: amount,
            amountOriginal: amountOriginal,
            currencyOriginal: currencyOriginal,
            fxRateToBase: fxRateToBase,
            fxSource: fxSource,
            fxStatus: fxStatus,
            category: category,
            subcategory: subcategory,
            account: accountLabel,
            note: note,
            date: date,
            periodYear: periodYear,
            periodMonth: periodMonth,
            createdAt: createdAt
        )
    }
}

@Model
final class CachedAccount {
    var id: UUID = UUID()
    var householdId: UUID = UUID()
    var name: String = ""
    var typeRaw: String = AccountType.other.rawValue
    var currency: String = "USD"
    var startingBalance: Decimal = Decimal(0)
    var institution: String?
    var accountNumberLast4: String?
    var icon: String?
    var color: String?
    var displayOrder: Int = 0
    var isActive: Bool = true
    var notes: String?
    var ownershipRaw: String = AccountOwnership.personal.rawValue
    var ownerUserId: UUID?
    var createdBy: UUID = UUID()
    var createdAt: Date?
    var updatedAt: Date?
    var syncedAt: Date = Date.distantPast

    init(_ a: Account, syncedAt: Date) {
        self.id = a.id
        self.householdId = a.householdId
        self.name = a.name
        self.typeRaw = a.type.rawValue
        self.currency = a.currency
        self.startingBalance = a.startingBalance
        self.institution = a.institution
        self.accountNumberLast4 = a.accountNumberLast4
        self.icon = a.icon
        self.color = a.color
        self.displayOrder = a.displayOrder
        self.isActive = a.isActive
        self.notes = a.notes
        self.ownershipRaw = a.ownership.rawValue
        self.ownerUserId = a.ownerUserId
        self.createdBy = a.createdBy
        self.createdAt = a.createdAt
        self.updatedAt = a.updatedAt
        self.syncedAt = syncedAt
    }

    func toDomain() -> Account {
        Account(
            id: id,
            householdId: householdId,
            name: name,
            type: AccountType(rawValue: typeRaw) ?? .other,
            currency: currency,
            startingBalance: startingBalance,
            institution: institution,
            accountNumberLast4: accountNumberLast4,
            icon: icon,
            color: color,
            displayOrder: displayOrder,
            isActive: isActive,
            notes: notes,
            ownership: AccountOwnership(rawValue: ownershipRaw) ?? .personal,
            ownerUserId: ownerUserId,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class CachedBill {
    var id: UUID = UUID()
    var householdId: UUID = UUID()
    var title: String = ""
    /// Mapea a `Bill.description` — `description` está tomado por
    /// `CustomStringConvertible` en una clase.
    var details: String?
    var amount: Decimal = Decimal(0)
    var currency: String = "USD"
    var dueDate: Date = Date.distantPast
    var statusRaw: String = BillStatus.pending.rawValue
    var paidAt: Date?
    var category: String?
    var accountId: UUID?
    var note: String?
    var recurring: Bool = false
    var createdBy: UUID = UUID()
    var createdAt: Date?
    var updatedAt: Date?
    var syncedAt: Date = Date.distantPast

    init(_ b: Bill, syncedAt: Date) {
        self.id = b.id
        self.householdId = b.householdId
        self.title = b.title
        self.details = b.description
        self.amount = b.amount
        self.currency = b.currency
        self.dueDate = b.dueDate
        self.statusRaw = b.status.rawValue
        self.paidAt = b.paidAt
        self.category = b.category
        self.accountId = b.accountId
        self.note = b.note
        self.recurring = b.recurring
        self.createdBy = b.createdBy
        self.createdAt = b.createdAt
        self.updatedAt = b.updatedAt
        self.syncedAt = syncedAt
    }

    func toDomain() -> Bill {
        Bill(
            id: id,
            householdId: householdId,
            title: title,
            description: details,
            amount: amount,
            currency: currency,
            dueDate: dueDate,
            status: BillStatus(rawValue: statusRaw) ?? .pending,
            paidAt: paidAt,
            category: category,
            accountId: accountId,
            note: note,
            recurring: recurring,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class CachedGoal {
    var id: UUID = UUID()
    var householdId: UUID = UUID()
    var name: String = ""
    var details: String?
    var targetAmount: Decimal = Decimal(0)
    var currentAmount: Decimal = Decimal(0)
    var currency: String = "USD"
    var targetDate: Date?
    var statusRaw: String = GoalStatus.active.rawValue
    var icon: String?
    var color: String?
    var priority: Int = 0
    var category: String?
    var accountId: UUID?
    var notes: String?
    var createdBy: UUID = UUID()
    var createdAt: Date?
    var updatedAt: Date?
    var completedAt: Date?
    var syncedAt: Date = Date.distantPast

    init(_ g: Goal, syncedAt: Date) {
        self.id = g.id
        self.householdId = g.householdId
        self.name = g.name
        self.details = g.description
        self.targetAmount = g.targetAmount
        self.currentAmount = g.currentAmount
        self.currency = g.currency
        self.targetDate = g.targetDate
        self.statusRaw = g.status.rawValue
        self.icon = g.icon
        self.color = g.color
        self.priority = g.priority
        self.category = g.category
        self.accountId = g.accountId
        self.notes = g.notes
        self.createdBy = g.createdBy
        self.createdAt = g.createdAt
        self.updatedAt = g.updatedAt
        self.completedAt = g.completedAt
        self.syncedAt = syncedAt
    }

    func toDomain() -> Goal {
        Goal(
            id: id,
            householdId: householdId,
            name: name,
            description: details,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            currency: currency,
            targetDate: targetDate,
            status: GoalStatus(rawValue: statusRaw) ?? .active,
            icon: icon,
            color: color,
            priority: priority,
            category: category,
            accountId: accountId,
            notes: notes,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }
}

/// Ventana temporal efectivamente cubierta por el cache de una entidad en un
/// hogar. Sin esto, un fetch chico (el mes actual) dejaría el cache "pisando"
/// al de un fetch grande (el año) y offline serviríamos un subconjunto SIN
/// avisar → un reporte anual mostraría un mes y parecería completo. En una app
/// de plata eso es peor que no mostrar nada: solo servimos cache cuando la
/// ventana pedida está CONTENIDA en la cubierta.
@Model
final class CachedWindow {
    /// `"transactions"` | `"accounts"` | `"bills"` | `"goals"`.
    ///
    /// ⚠️ NO renombrar a `entity`: es un nombre reservado de CoreData
    /// (`NSManagedObject.entity`) y SwiftData traduce el predicado contra la
    /// `NSEntityDescription` → `"transactions" is not a valid entity name`,
    /// una `NSInternalInconsistencyException` que ningún `try?` atrapa.
    var kind: String = ""
    var householdId: UUID = UUID()
    var from: Date = Date.distantPast
    var to: Date = Date.distantPast
    var syncedAt: Date = Date.distantPast

    init(kind: String, householdId: UUID, from: Date, to: Date, syncedAt: Date) {
        self.kind = kind
        self.householdId = householdId
        self.from = from
        self.to = to
        self.syncedAt = syncedAt
    }
}

// MARK: - LocalStore

/// Dueño del `ModelContainer` del cache offline.
///
/// **Nunca crashea**: si el store no abre (archivo corrupto, migración
/// imposible, disco lleno) se intenta UNA vez borrarlo y recrearlo; si tampoco
/// así, `container` queda en `nil` y la app corre en *modo sin-cache* — todo
/// sigue funcionando exactamente como antes de esta feature (red o error).
/// La app está publicada: un `try!` acá sería un crash masivo en producción.
enum LocalStore {
    private static let log = Logger(subsystem: "com.metacasa.app", category: "OfflineCache")

    static let schema = Schema([
        CachedTransaction.self,
        CachedAccount.self,
        CachedBill.self,
        CachedGoal.self,
        CachedWindow.self
    ])

    /// `nil` ⇒ modo sin-cache. Todos los callers deben tolerarlo.
    static let container: ModelContainer? = makeContainer()

    /// `true` si el cache offline está operativo.
    static var isAvailable: Bool { container != nil }

    private static func makeContainer() -> ModelContainer? {
        // `isStoredInMemoryOnly: false` → persiste en disco (el punto de la
        // feature: sobrevivir a cerrar la app y quedarse sin red).
        // `groupContainer: .none` a propósito: con `.automatic` el store cae en
        // el App Group compartido con la widget extension (que no lo necesita:
        // los widgets leen `WidgetSnapshot`) y CoreData arranca fallando porque
        // ahí no existe `Application Support`.
        let config = ModelConfiguration(
            "MetaCasaOfflineCache",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            log.error("ModelContainer no abrió: \(error.localizedDescription, privacy: .public). Reintento con store limpio.")
            ObservabilityService.captureError(error, context: "offline-cache-open")
            destroyStore(at: config.url)
            do {
                let recovered = try ModelContainer(for: schema, configurations: config)
                log.notice("ModelContainer recuperado tras borrar el store.")
                return recovered
            } catch {
                log.error("ModelContainer sigue sin abrir: \(error.localizedDescription, privacy: .public). Modo sin-cache.")
                ObservabilityService.captureError(error, context: "offline-cache-open-retry")
                return nil
            }
        }
    }

    /// Borra el .store y sus sidecars WAL/SHM. Best-effort: no tiene sentido
    /// propagar errores acá, el caller ya está en camino de degradación.
    private static func destroyStore(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let candidate = URL(fileURLWithPath: url.path + suffix)
            try? fm.removeItem(at: candidate)
        }
    }
}
