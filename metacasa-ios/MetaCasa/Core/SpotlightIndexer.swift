import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Indexa transacciones y metas del hogar activo al índice de Spotlight
/// del sistema iOS, para que aparezcan en búsquedas desde el home screen
/// y desde la app Files.
///
/// Estrategia:
/// - Al entrar a background o después de un load exitoso del Home, se
///   dispara `reindex()`.
/// - Indexamos últimas 180 días de transacciones + todas las metas activas.
/// - Cada item tiene `domainIdentifier` por tipo ("tx" / "goal") para poder
///   limpiar selectivamente.
/// - `contentType = UTType.content.identifier` y `uniqueIdentifier = UUID.uuidString`.
///
/// Deep linking: cuando el user toca un resultado de Spotlight, el sistema
/// abre la app con `NSUserActivity.activityType =
/// "com.apple.corespotlight.searchableitemaction"` y el id en `userInfo`.
/// El `handleSpotlightActivity(_:)` en `RootView` puede parsear el prefix
/// para decidir a qué vista navegar.
///
/// Privacy: los items indexados solo viven en el índice local del iPhone.
/// No se sincronizan con iCloud ni se exponen a terceros. Si el user borra
/// los datos de la app, el indexer llama `deleteAll()` para dejar el índice
/// limpio.
@MainActor
enum SpotlightIndexer {
    /// Prefijos para identificar items por tipo en el indexer.
    enum Prefix: String {
        case transaction = "tx"
        case goal = "goal"
    }

    /// Domain identifiers (group-level) para deleteAllForDomain.
    private static let txDomain = "com.metacasa.spotlight.transactions"
    private static let goalDomain = "com.metacasa.spotlight.goals"

    /// Re-indexa transacciones (últimos 180 días) + metas activas del
    /// hogar activo. Si falla, loguea y sigue. No bloquea el UI.
    static func reindex(
        transactions: [Transaction],
        goals: [Goal],
        currency: String
    ) async {
        let index = CSSearchableIndex.default()

        // 1. Transactions items.
        let txItems: [CSSearchableItem] = transactions.prefix(500).map { tx in
            makeTransactionItem(tx: tx, currency: currency)
        }

        // 2. Goals items.
        let goalItems: [CSSearchableItem] = goals.map { goal in
            makeGoalItem(goal: goal)
        }

        let all = txItems + goalItems
        do {
            try await index.indexSearchableItems(all)
            #if DEBUG
            print("[Spotlight] indexed \(txItems.count) tx + \(goalItems.count) goals")
            #endif
        } catch {
            #if DEBUG
            print("[Spotlight] indexing failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Borra TODOS los items indexados. Se llama en signOut o delete account.
    static func deleteAll() async {
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [txDomain, goalDomain])
        } catch {
            #if DEBUG
            print("[Spotlight] deleteAll failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Parsea un `NSUserActivity` del tipo `CSSearchableItemActionType` y
    /// devuelve el tipo + id del item que tocó el user. El caller decide
    /// a qué vista navegar.
    static func parseActivity(_ activity: NSUserActivity) -> SpotlightHit? {
        guard activity.activityType == CSSearchableItemActionType,
              let rawID = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        let parts = rawID.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let prefix = Prefix(rawValue: String(parts[0])) else {
            return nil
        }
        return SpotlightHit(prefix: prefix, uuid: String(parts[1]))
    }

    // MARK: - Item builders

    private static func makeTransactionItem(tx: Transaction, currency: String) -> CSSearchableItem {
        let attr = CSSearchableItemAttributeSet(contentType: UTType.content)
        let typeEmoji = tx.type == .gasto ? "💸" : "💰"
        let amountFmt = Money.format(tx.amount, currency: tx.currencyOriginal ?? currency, style: .compact)
        attr.title = "\(typeEmoji) \(tx.category) · \(amountFmt)"
        let df = DateFormatter()
        df.locale = AppLocaleStorage.effectiveLocale
        df.setLocalizedDateFormatFromTemplate("ddMMMyyyy")
        let dateStr = df.string(from: tx.date)
        var descParts: [String] = [dateStr]
        if let sub = tx.subcategory, !sub.isEmpty { descParts.append(sub) }
        if let note = tx.note, !note.isEmpty { descParts.append(note) }
        attr.contentDescription = descParts.joined(separator: " · ")
        attr.keywords = [tx.category, tx.subcategory ?? "", tx.note ?? "", "MetaCasa"].filter { !$0.isEmpty }
        attr.thumbnailData = nil

        let id = "\(Prefix.transaction.rawValue):\(tx.id.uuidString)"
        let item = CSSearchableItem(
            uniqueIdentifier: id,
            domainIdentifier: txDomain,
            attributeSet: attr
        )
        item.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        return item
    }

    private static func makeGoalItem(goal: Goal) -> CSSearchableItem {
        let attr = CSSearchableItemAttributeSet(contentType: UTType.content)
        let pct = Int(goal.progress * 100)
        attr.title = "🎯 \(goal.name) · \(pct)%"
        let remaining = max(0, goal.targetAmount - goal.currentAmount)
        attr.contentDescription = String(
            localized: "spotlight.goal.description \(Money.format(remaining, currency: goal.currency, style: .compact)) \(pct)"
        )
        attr.keywords = [goal.name, "meta", "goal", "ahorro", "MetaCasa"]

        let id = "\(Prefix.goal.rawValue):\(goal.id.uuidString)"
        let item = CSSearchableItem(
            uniqueIdentifier: id,
            domainIdentifier: goalDomain,
            attributeSet: attr
        )
        item.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        return item
    }
}

// MARK: - Hit model

struct SpotlightHit: Sendable, Equatable {
    let prefix: SpotlightIndexer.Prefix
    let uuid: String
}
