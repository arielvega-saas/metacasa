import Foundation
import Observation

/// Estado global "lo que estás viendo NO viene del servidor".
///
/// Regla de producto (app de finanzas): jamás mostrar números viejos como si
/// fueran de ahora. Cada vez que un service sirve datos del cache lo reporta
/// acá, y `OfflineBanner` lo hace visible con la fecha del último sync.
@MainActor
@Observable
final class OfflineStatus {
    static let shared = OfflineStatus()
    private init() {}

    /// `true` mientras haya datos en pantalla que salieron del cache.
    private(set) var isServingCachedData = false

    /// Sync más viejo entre los datos cacheados que se están mostrando.
    private(set) var cachedSince: Date?

    /// Última vez que un service sirvió cache. Ver `noteFreshData()`.
    private var lastCacheHitAt: Date?

    /// Ventana en la que un dato fresco NO alcanza para limpiar el aviso.
    /// El Home dispara ~10 requests en paralelo: si dos fallan por red y ocho
    /// responden, la pantalla es MIXTA y avisar es lo correcto. Sin esta
    /// ventana, el último request en terminar decidiría el cartel al azar.
    private static let mixedLoadWindow: TimeInterval = 3

    func noteCachedData(syncedAt: Date) {
        lastCacheHitAt = Date()
        isServingCachedData = true
        // Nos quedamos con el sync MÁS VIEJO: el cartel tiene que reflejar
        // la peor antigüedad que hay en pantalla, no la mejor.
        cachedSince = min(cachedSince ?? syncedAt, syncedAt)
    }

    func noteFreshData() {
        if let last = lastCacheHitAt,
           Date().timeIntervalSince(last) < Self.mixedLoadWindow {
            return
        }
        lastCacheHitAt = nil
        isServingCachedData = false
        cachedSince = nil
    }

    /// signOut / deleteAccount / cambio de hogar.
    func reset() {
        lastCacheHitAt = nil
        isServingCachedData = false
        cachedSince = nil
    }
}

extension OfflineStatus {
    /// Reporte desde los services (que son `actor`s, no `@MainActor`). No
    /// bloquea: el service no espera al hop al main thread para devolver.
    nonisolated static func reportCachedData(syncedAt: Date) {
        Task { @MainActor in shared.noteCachedData(syncedAt: syncedAt) }
    }

    nonisolated static func reportFreshData() {
        Task { @MainActor in shared.noteFreshData() }
    }
}
