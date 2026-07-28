import Foundation

// MARK: - HomeSnapshot

/// Snapshot Codable de todo lo que el Home necesita para pintar al instante
/// en cold start, sin esperar la red (ítem 3.3 del plan de mejoras).
///
/// Nota de shape: sparklines, streak, health score y top gastos NO se guardan
/// pre-computados — derivan de `recentTransactions` (las transacciones del mes
/// que el Home ya baja con limit 500), que sí viaja en el snapshot. Así los
/// computed properties del `HomeViewModel` siguen siendo la única fuente de
/// esas derivaciones y no hay dos caminos que puedan divergir.
struct HomeSnapshot: Codable, Sendable {
    /// Subir cuando cambie el shape → snapshots viejos se descartan en
    /// silencio (mejor un skeleton que crashear decodificando).
    static let currentSchemaVersion = 1

    var schemaVersion: Int = HomeSnapshot.currentSchemaVersion
    var savedAt: Date = Date()

    // Totales del mes + mes anterior
    var totalIngresos: Decimal = 0
    var totalGastos: Decimal = 0
    var prevMonthIngresos: Decimal = 0
    var prevMonthGastos: Decimal = 0

    /// Transacciones del mes (≤500). De acá derivan sparklines, streak,
    /// health score, top gastos y el sheet de desglose.
    var recentTransactions: [Transaction] = []

    var period: BudgetPeriod?
    var upcomingBills: [Bill] = []
    var activeGoals: [Goal] = []
    var templates: [TransactionTemplate] = []
    var topCategories: [CategoryTotal] = []
    var netWorth: NetWorthBreakdown = .zero

    // Counts / compromisos
    var activeDebtsCount: Int = 0
    var activePlansCount: Int = 0
    var monthlyDebtCommitment: Decimal = 0

    struct CategoryTotal: Codable, Sendable {
        var category: String
        var total: Decimal
    }
}

// MARK: - HomeSnapshotStore

/// Persistencia en disco del `HomeSnapshot`: un archivo JSON por hogar en
/// Application Support (`HomeSnapshots/<householdId>.json`).
///
/// Uso (ver `HomeViewModel.load`):
/// 1. Cold start: si hay snapshot → aplicarlo INMEDIATAMENTE (sin flash de
///    skeleton) y refrescar de red en silencio.
/// 2. Tras cada load de red exitoso → re-guardar el snapshot.
/// 3. En signOut/deleteAccount → `clearAll()` para no dejar data financiera
///    de la cuenta anterior en disco.
actor HomeSnapshotStore {
    static let shared = HomeSnapshotStore()
    private init() {}

    private func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("HomeSnapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for householdId: UUID) throws -> URL {
        try directory().appendingPathComponent("\(householdId.uuidString.lowercased()).json")
    }

    /// Último snapshot guardado del hogar, o `nil` si no hay / no decodifica /
    /// es de un schema viejo.
    func load(householdId: UUID) -> HomeSnapshot? {
        guard let url = try? fileURL(for: householdId),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(HomeSnapshot.self, from: data),
              snapshot.schemaVersion == HomeSnapshot.currentSchemaVersion
        else { return nil }
        return snapshot
    }

    /// Persiste el snapshot de forma atómica. `.completeFileProtection`:
    /// data financiera cifrada at-rest por iOS mientras el device está
    /// bloqueado. Best-effort — un fallo de escritura nunca rompe el Home.
    func save(_ snapshot: HomeSnapshot, householdId: UUID) {
        guard let url = try? fileURL(for: householdId),
              let data = try? JSONEncoder().encode(snapshot)
        else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Borra todos los snapshots de todos los hogares.
    func clearAll() {
        guard let dir = try? directory() else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}
