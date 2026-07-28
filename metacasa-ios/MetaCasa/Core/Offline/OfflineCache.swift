import Foundation
import SwiftData
import os

// MARK: - Payload

/// Resultado servido desde el cache local, siempre acompañado de CUÁNDO se
/// sincronizó. Nunca devolvemos datos viejos sin su fecha: la UI está obligada
/// a poder decirle al usuario qué antigüedad tiene lo que está viendo.
struct CachedPayload<Item: Sendable>: Sendable {
    let items: [Item]
    /// Sync más VIEJO entre las filas devueltas (criterio conservador: si la
    /// lista mezcla filas de distintos fetches, mostramos la peor).
    let syncedAt: Date
}

// MARK: - Política de fallback

/// Decide si un error habilita servir datos cacheados.
///
/// **La distinción es el corazón de esta feature**: un problema de RED es
/// transitorio y el usuario prefiere ver sus datos de ayer antes que una
/// pantalla vacía. Un problema de AUTH (401/403) o un 4xx significan que el
/// request estaba mal o la sesión murió: ahí servir cache TAPARÍA el problema,
/// el `SupabaseRPC` no podría disparar su refresh de JWT y el usuario quedaría
/// mirando datos viejos para siempre sin entender por qué no se actualizan.
enum OfflineFallbackPolicy {

    /// Códigos de `NSURLErrorDomain` que significan "no se pudo hablar con el
    /// servidor". Se excluyen a propósito `cancelled` / `userCancelled`
    /// (la operación se abortó, no hubo falla) y `userAuthenticationRequired`.
    private static let networkFailureCodes: Set<Int> = [
        URLError.Code.notConnectedToInternet.rawValue,
        URLError.Code.networkConnectionLost.rawValue,
        URLError.Code.timedOut.rawValue,
        URLError.Code.cannotConnectToHost.rawValue,
        URLError.Code.cannotFindHost.rawValue,
        URLError.Code.dnsLookupFailed.rawValue,
        URLError.Code.internationalRoamingOff.rawValue,
        URLError.Code.dataNotAllowed.rawValue,
        URLError.Code.callIsActive.rawValue,
        URLError.Code.resourceUnavailable.rawValue,
        URLError.Code.secureConnectionFailed.rawValue,
        URLError.Code.cannotLoadFromNetwork.rawValue,
        URLError.Code.backgroundSessionWasDisconnected.rawValue
    ]

    static func allowsCachedFallback(for error: Error) -> Bool {
        // Cancelación: la tarea se abortó (el user cambió de pantalla). No es
        // una falla de red y pintar cache acá sería ruido.
        if error is CancellationError { return false }
        // Decode roto = bug nuestro o cambio de schema. Que se vea.
        if error is DecodingError { return false }

        let ns = error as NSError
        switch ns.domain {
        case NSURLErrorDomain:
            return networkFailureCodes.contains(ns.code)

        case "SupabaseRPC":
            // `SupabaseRPC` codifica el status HTTP en `code`.
            // - 0   → la respuesta no fue HTTP (proxy/captive portal) ⇒ red.
            // - 5xx → el backend está caído; para el usuario es indistinguible
            //         de no tener red, y no hay nada que reintentar en el device.
            // - 401 / 403 / 4xx → NUNCA cache. El 401 tiene que propagarse
            //         para que la sesión se renueve o se fuerce el relogin.
            if ns.code == 0 { return true }
            if (500...599).contains(ns.code) { return true }
            return false

        default:
            return false
        }
    }
}

// MARK: - OfflineCache

/// Actor dueño de las escrituras y lecturas del cache offline (SwiftData).
///
/// Todo el trabajo de disco corre en el ejecutor del actor — nunca en el main
/// thread. Los services escriben con `Task.detached(priority: .utility)` para
/// no hacer esperar a la UI por el `save()`.
///
/// **Read-only mirror**: acá NO hay cola de mutaciones pendientes. Escribir
/// offline es otra apuesta (conflictos, orden, reintentos) y está fuera de
/// alcance a propósito.
actor OfflineCache {
    static let shared = OfflineCache()
    private init() {}

    private let log = Logger(subsystem: "com.metacasa.app", category: "OfflineCache")
    private var contextStorage: ModelContext?

    /// `false` ⇒ el store no abrió; toda operación es no-op y la app funciona
    /// como antes de esta feature.
    var isAvailable: Bool { LocalStore.isAvailable }

    private func context() -> ModelContext? {
        if let c = contextStorage { return c }
        guard let container = LocalStore.container else { return nil }
        let c = ModelContext(container)
        // Guardamos explícitamente al final de cada replace: queremos que un
        // fallo de escritura sea visible acá y no en un autosave difuso.
        c.autosaveEnabled = false
        contextStorage = c
        return c
    }

    // MARK: - Ventanas de cobertura

    private func fetchWindow(_ entityKey: String, householdId: UUID, in ctx: ModelContext) -> CachedWindow? {
        var d = FetchDescriptor<CachedWindow>(
            predicate: #Predicate { $0.kind == entityKey && $0.householdId == householdId }
        )
        d.fetchLimit = 1
        return (try? ctx.fetch(d))?.first
    }

    private func upsertWindow(
        _ entityKey: String,
        householdId: UUID,
        from: Date,
        to: Date,
        syncedAt: Date,
        in ctx: ModelContext
    ) {
        if let existing = fetchWindow(entityKey, householdId: householdId, in: ctx) {
            existing.from = from
            existing.to = to
            existing.syncedAt = syncedAt
        } else {
            ctx.insert(CachedWindow(
                kind: entityKey,
                householdId: householdId,
                from: from,
                to: to,
                syncedAt: syncedAt
            ))
        }
    }

    /// Borrado por lote con fallback a borrado fila por fila: la API de batch
    /// delete de SwiftData no es uniforme entre versiones de iOS y un throw acá
    /// no puede tumbar el cache entero.
    private func deleteAll<T: PersistentModel>(
        _ type: T.Type,
        where predicate: Predicate<T>?,
        in ctx: ModelContext
    ) {
        do {
            try ctx.delete(model: type, where: predicate)
        } catch {
            log.error("Batch delete falló (\(String(describing: type), privacy: .public)); fallback fila por fila.")
            let descriptor = FetchDescriptor<T>(predicate: predicate)
            if let rows = try? ctx.fetch(descriptor) {
                for row in rows { ctx.delete(row) }
            }
        }
    }

    private func commit(_ ctx: ModelContext, op: String) {
        do {
            try ctx.save()
        } catch {
            log.error("save() falló en \(op, privacy: .public): \(error.localizedDescription, privacy: .public)")
            ctx.rollback()
        }
    }

    // MARK: - Transactions

    /// Refresca el cache de transacciones para la ventana `[from, to]`.
    ///
    /// Si el fetch se cortó por `requestedLimit`, el set devuelto solo es
    /// COMPLETO desde la fecha más vieja recibida (PostgREST ordena por fecha
    /// desc) — la cobertura se recorta a eso para no afirmar de más.
    func replace(
        transactions rows: [Transaction],
        householdId: UUID,
        from: Date,
        to: Date,
        requestedLimit: Int
    ) {
        guard let ctx = context() else { return }
        let now = Date()

        let truncated = requestedLimit > 0 && rows.count >= requestedLimit
        let effectiveFrom = truncated ? (rows.map(\.date).min() ?? from) : from

        var coverFrom = effectiveFrom
        var coverTo = to
        var wipeHousehold = false

        if let existing = fetchWindow("transactions", householdId: householdId, in: ctx) {
            // ¿Se solapan o se tocan? Entonces la unión es contigua y podemos
            // afirmar cobertura sobre todo el rango.
            if existing.from <= to && effectiveFrom <= existing.to {
                coverFrom = min(existing.from, effectiveFrom)
                coverTo = max(existing.to, to)
            } else {
                // Ventanas disjuntas ⇒ quedaría un hueco invisible en el medio.
                // Nos quedamos SOLO con la nueva.
                wipeHousehold = true
            }
        }

        if wipeHousehold {
            deleteAll(
                CachedTransaction.self,
                where: #Predicate { $0.householdId == householdId },
                in: ctx
            )
        } else {
            deleteAll(
                CachedTransaction.self,
                where: #Predicate {
                    $0.householdId == householdId && $0.date >= effectiveFrom && $0.date <= to
                },
                in: ctx
            )
        }

        for tx in rows { ctx.insert(CachedTransaction(tx, syncedAt: now)) }
        upsertWindow("transactions", householdId: householdId, from: coverFrom, to: coverTo, syncedAt: now, in: ctx)
        commit(ctx, op: "replace(transactions)")
    }

    /// Devuelve las transacciones cacheadas de la ventana pedida, o `nil` si el
    /// cache NO cubre ese rango (nunca se sincronizó, o solo se sincronizó un
    /// subconjunto). Devolver un subconjunto haciéndolo pasar por completo
    /// falsearía totales — preferimos que el caller propague el error de red.
    func loadTransactions(householdId: UUID, from: Date, to: Date, limit: Int) -> CachedPayload<Transaction>? {
        guard let ctx = context(),
              let window = fetchWindow("transactions", householdId: householdId, in: ctx),
              window.from <= from, window.to >= to
        else { return nil }

        var d = FetchDescriptor<CachedTransaction>(
            predicate: #Predicate { $0.householdId == householdId && $0.date >= from && $0.date <= to },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if limit > 0 { d.fetchLimit = limit }
        guard let rows = try? ctx.fetch(d) else { return nil }

        let deduped = Self.dedupe(rows, id: \.id)
        let items = deduped.map { $0.toDomain() }
        let syncedAt = deduped.map(\.syncedAt).min() ?? window.syncedAt
        return CachedPayload(items: items, syncedAt: syncedAt)
    }

    // MARK: - Accounts

    func replace(accounts rows: [Account], householdId: UUID) {
        guard let ctx = context() else { return }
        let now = Date()
        deleteAll(CachedAccount.self, where: #Predicate { $0.householdId == householdId }, in: ctx)
        for a in rows { ctx.insert(CachedAccount(a, syncedAt: now)) }
        upsertWindow("accounts", householdId: householdId, from: .distantPast, to: .distantFuture, syncedAt: now, in: ctx)
        commit(ctx, op: "replace(accounts)")
    }

    /// Nota de alcance: el cache guarda lo último que se pidió por red. Como
    /// casi todos los callers piden solo activas, pedir `includingInactive`
    /// offline puede devolver menos filas de las que hay en el servidor. Va
    /// siempre etiquetado como dato cacheado.
    func loadAccounts(householdId: UUID, includingInactive: Bool) -> CachedPayload<Account>? {
        guard let ctx = context(),
              let window = fetchWindow("accounts", householdId: householdId, in: ctx)
        else { return nil }

        let d = FetchDescriptor<CachedAccount>(
            predicate: #Predicate { $0.householdId == householdId },
            sortBy: [SortDescriptor(\.displayOrder, order: .forward)]
        )
        guard let rows = try? ctx.fetch(d) else { return nil }

        let deduped = Self.dedupe(rows, id: \.id)
            .filter { includingInactive || $0.isActive }
        let syncedAt = deduped.map(\.syncedAt).min() ?? window.syncedAt
        return CachedPayload(items: deduped.map { $0.toDomain() }, syncedAt: syncedAt)
    }

    // MARK: - Bills

    /// El cache de vencimientos espeja `BillService.fetchUpcoming`: pendientes
    /// con `dueDate <= cutoff` (incluye vencidos, que no tienen piso).
    func replace(upcomingBills rows: [Bill], householdId: UUID, cutoff: Date) {
        guard let ctx = context() else { return }
        let now = Date()

        var coverTo = cutoff
        if let existing = fetchWindow("bills", householdId: householdId, in: ctx) {
            coverTo = max(existing.to, cutoff)
        }
        // Borramos solo el tramo que este fetch puede afirmar; lo que estaba
        // cacheado más allá del cutoff sigue siendo válido.
        deleteAll(
            CachedBill.self,
            where: #Predicate { $0.householdId == householdId && $0.dueDate <= cutoff },
            in: ctx
        )
        for b in rows { ctx.insert(CachedBill(b, syncedAt: now)) }
        upsertWindow("bills", householdId: householdId, from: .distantPast, to: coverTo, syncedAt: now, in: ctx)
        commit(ctx, op: "replace(bills)")
    }

    /// Tolerancia de 3 días en la cobertura: el cutoff se calcula con `Date()`
    /// en cada llamada, así que un cache de ayer queda "corto" por unas horas
    /// aunque tenga exactamente el mismo horizonte. Sin la tolerancia el cache
    /// de vencimientos sería inútil apenas pasa la medianoche.
    func loadUpcomingBills(householdId: UUID, cutoff: Date) -> CachedPayload<Bill>? {
        guard let ctx = context(),
              let window = fetchWindow("bills", householdId: householdId, in: ctx),
              window.to >= cutoff.addingTimeInterval(-3 * 86_400)
        else { return nil }

        let d = FetchDescriptor<CachedBill>(
            predicate: #Predicate {
                $0.householdId == householdId
                    && $0.dueDate <= cutoff
                    && $0.statusRaw == "pending"
            },
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        guard let rows = try? ctx.fetch(d) else { return nil }

        let deduped = Self.dedupe(rows, id: \.id)
        let syncedAt = deduped.map(\.syncedAt).min() ?? window.syncedAt
        return CachedPayload(items: deduped.map { $0.toDomain() }, syncedAt: syncedAt)
    }

    // MARK: - Goals

    func replace(goals rows: [Goal], householdId: UUID) {
        guard let ctx = context() else { return }
        let now = Date()
        deleteAll(CachedGoal.self, where: #Predicate { $0.householdId == householdId }, in: ctx)
        for g in rows { ctx.insert(CachedGoal(g, syncedAt: now)) }
        upsertWindow("goals", householdId: householdId, from: .distantPast, to: .distantFuture, syncedAt: now, in: ctx)
        commit(ctx, op: "replace(goals)")
    }

    func loadGoals(householdId: UUID, includeCompleted: Bool) -> CachedPayload<Goal>? {
        guard let ctx = context(),
              let window = fetchWindow("goals", householdId: householdId, in: ctx)
        else { return nil }

        let d = FetchDescriptor<CachedGoal>(
            predicate: #Predicate { $0.householdId == householdId },
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )
        guard let rows = try? ctx.fetch(d) else { return nil }

        let deduped = Self.dedupe(rows, id: \.id)
            .filter { includeCompleted || $0.statusRaw != GoalStatus.completed.rawValue }
        let syncedAt = deduped.map(\.syncedAt).min() ?? window.syncedAt
        return CachedPayload(items: deduped.map { $0.toDomain() }, syncedAt: syncedAt)
    }

    // MARK: - Limpieza

    /// Vacía TODO el cache. Se llama en `signOut` / `deleteAccount`: no puede
    /// quedar data financiera de la cuenta anterior en disco (mismo criterio
    /// que `HomeSnapshotStore.clearAll`).
    func clearAll() {
        guard let ctx = context() else { return }
        deleteAll(CachedTransaction.self, where: nil, in: ctx)
        deleteAll(CachedAccount.self, where: nil, in: ctx)
        deleteAll(CachedBill.self, where: nil, in: ctx)
        deleteAll(CachedGoal.self, where: nil, in: ctx)
        deleteAll(CachedWindow.self, where: nil, in: ctx)
        commit(ctx, op: "clearAll")
    }

    // MARK: - Helpers

    /// Sin `@Attribute(.unique)` (que en SwiftData puede explotar cuando un
    /// delete y un insert del mismo id caen en el mismo save), así que
    /// deduplicamos al leer: mostrar un movimiento dos veces en una app de
    /// plata sería peor que no mostrarlo.
    private static func dedupe<T>(_ rows: [T], id: KeyPath<T, UUID>) -> [T] {
        var seen = Set<UUID>()
        var out: [T] = []
        out.reserveCapacity(rows.count)
        for row in rows where seen.insert(row[keyPath: id]).inserted {
            out.append(row)
        }
        return out
    }
}
