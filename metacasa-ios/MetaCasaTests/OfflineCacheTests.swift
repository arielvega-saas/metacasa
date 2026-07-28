import XCTest
@testable import Home_Finance

/// Cobertura del cache offline (ítem 4.1). Lo que se testea acá es lo que puede
/// mentirle al usuario: qué error habilita servir datos viejos y si el cache
/// afirma cubrir ventanas que no cubre.
final class OfflineFallbackPolicyTests: XCTestCase {

    private func urlError(_ code: URLError.Code) -> Error {
        NSError(domain: NSURLErrorDomain, code: code.rawValue)
    }

    private func rpcError(_ status: Int) -> Error {
        NSError(domain: "SupabaseRPC", code: status,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"])
    }

    func testSinConexionHabilitaCache() {
        XCTAssertTrue(OfflineFallbackPolicy.allowsCachedFallback(for: urlError(.notConnectedToInternet)))
        XCTAssertTrue(OfflineFallbackPolicy.allowsCachedFallback(for: urlError(.networkConnectionLost)))
        XCTAssertTrue(OfflineFallbackPolicy.allowsCachedFallback(for: urlError(.timedOut)))
        XCTAssertTrue(OfflineFallbackPolicy.allowsCachedFallback(for: urlError(.cannotConnectToHost)))
        XCTAssertTrue(OfflineFallbackPolicy.allowsCachedFallback(for: urlError(.dnsLookupFailed)))
    }

    /// El caso crítico: un 401 tiene que PROPAGARSE para que la sesión se
    /// renueve. Si lo tapáramos con cache, el usuario vería datos viejos para
    /// siempre sin entender por qué no se actualizan.
    func testAuthNuncaSirveCache() {
        XCTAssertFalse(OfflineFallbackPolicy.allowsCachedFallback(for: rpcError(401)))
        XCTAssertFalse(OfflineFallbackPolicy.allowsCachedFallback(for: rpcError(403)))
    }

    func testCuatroXXNuncaSirveCache() {
        for status in [400, 404, 409, 422, 429] {
            XCTAssertFalse(
                OfflineFallbackPolicy.allowsCachedFallback(for: rpcError(status)),
                "HTTP \(status) no debería servir cache"
            )
        }
    }

    /// Backend caído: para el usuario es indistinguible de no tener red y no
    /// hay nada que el device pueda arreglar reintentando distinto.
    func testCincoXXYRespuestaInvalidaSirvenCache() {
        XCTAssertTrue(OfflineFallbackPolicy.allowsCachedFallback(for: rpcError(500)))
        XCTAssertTrue(OfflineFallbackPolicy.allowsCachedFallback(for: rpcError(503)))
        XCTAssertTrue(OfflineFallbackPolicy.allowsCachedFallback(for: rpcError(0)))
    }

    func testCancelacionYDecodeNoSirvenCache() {
        XCTAssertFalse(OfflineFallbackPolicy.allowsCachedFallback(for: CancellationError()))
        XCTAssertFalse(OfflineFallbackPolicy.allowsCachedFallback(for: urlError(.cancelled)))
        let decode = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))
        XCTAssertFalse(OfflineFallbackPolicy.allowsCachedFallback(for: decode))
    }
}

final class OfflineCacheStoreTests: XCTestCase {

    private let householdId = UUID()

    override func tearDown() async throws {
        await OfflineCache.shared.clearAll()
        try await super.tearDown()
    }

    private func makeTx(date: Date, amount: Decimal = 100) -> Transaction {
        Transaction(
            id: UUID(),
            householdId: householdId,
            userId: UUID(),
            accountId: nil,
            type: .gasto,
            amount: amount,
            amountOriginal: nil,
            currencyOriginal: nil,
            fxRateToBase: nil,
            fxSource: nil,
            fxStatus: nil,
            category: "Alimentación",
            subcategory: nil,
            account: nil,
            note: "test",
            date: date,
            periodYear: nil,
            periodMonth: nil,
            createdAt: nil
        )
    }

    private func skipIfUnavailable() async throws {
        let available = await OfflineCache.shared.isAvailable
        try XCTSkipUnless(available, "El store no abrió — la app corre en modo sin-cache")
    }

    func testRoundTripDeTransacciones() async throws {
        try await skipIfUnavailable()
        let to = Date()
        let from = to.addingTimeInterval(-30 * 86_400)
        let rows = [
            makeTx(date: to.addingTimeInterval(-86_400), amount: 10),
            makeTx(date: to.addingTimeInterval(-2 * 86_400), amount: 20)
        ]
        await OfflineCache.shared.replace(
            transactions: rows, householdId: householdId, from: from, to: to, requestedLimit: 200
        )

        let cached = await OfflineCache.shared.loadTransactions(
            householdId: householdId, from: from, to: to, limit: 200
        )
        let payload = try XCTUnwrap(cached)
        XCTAssertEqual(payload.items.count, 2)
        // Orden date desc, igual que PostgREST.
        XCTAssertEqual(payload.items.first?.amount, 10)
        XCTAssertEqual(Set(payload.items.map(\.id)), Set(rows.map(\.id)))
        XCTAssertLessThanOrEqual(payload.syncedAt, Date())
    }

    /// Lo importante de la ventana de cobertura: si solo cacheamos un mes, un
    /// pedido de un año NO puede devolver ese mes como si fuera el año entero.
    func testNoSirveVentanaMasAnchaQueLaCacheada() async throws {
        try await skipIfUnavailable()
        let to = Date()
        let from = to.addingTimeInterval(-30 * 86_400)
        await OfflineCache.shared.replace(
            transactions: [makeTx(date: to.addingTimeInterval(-86_400))],
            householdId: householdId, from: from, to: to, requestedLimit: 200
        )

        let wider = await OfflineCache.shared.loadTransactions(
            householdId: householdId,
            from: to.addingTimeInterval(-365 * 86_400),
            to: to,
            limit: 5000
        )
        XCTAssertNil(wider, "Una ventana no cubierta debe devolver nil, no un subconjunto")
    }

    func testSinSyncPreviaDevuelveNil() async throws {
        try await skipIfUnavailable()
        let otro = UUID()
        let cached = await OfflineCache.shared.loadTransactions(
            householdId: otro, from: Date().addingTimeInterval(-86_400), to: Date(), limit: 100
        )
        XCTAssertNil(cached)
    }

    func testClearAllVaciaElCache() async throws {
        try await skipIfUnavailable()
        let to = Date()
        let from = to.addingTimeInterval(-86_400)
        await OfflineCache.shared.replace(
            transactions: [makeTx(date: to)], householdId: householdId, from: from, to: to, requestedLimit: 200
        )
        await OfflineCache.shared.clearAll()

        let cached = await OfflineCache.shared.loadTransactions(
            householdId: householdId, from: from, to: to, limit: 200
        )
        XCTAssertNil(cached, "Después de signOut no puede quedar data financiera en disco")
    }

    func testGoalsRoundTripYFiltroDeCompletadas() async throws {
        try await skipIfUnavailable()
        func goal(_ status: GoalStatus) -> Goal {
            Goal(
                id: UUID(), householdId: householdId, name: "Meta", description: nil,
                targetAmount: 1000, currentAmount: 100, currency: "USD", targetDate: nil,
                status: status, icon: nil, color: nil, priority: 0, category: nil,
                accountId: nil, notes: nil, createdBy: UUID(), createdAt: Date(),
                updatedAt: nil, completedAt: nil
            )
        }
        await OfflineCache.shared.replace(
            goals: [goal(.active), goal(.completed)], householdId: householdId
        )

        let todasRaw = await OfflineCache.shared.loadGoals(householdId: householdId, includeCompleted: true)
        let todas = try XCTUnwrap(todasRaw)
        XCTAssertEqual(todas.items.count, 2)

        let activasRaw = await OfflineCache.shared.loadGoals(householdId: householdId, includeCompleted: false)
        let activas = try XCTUnwrap(activasRaw)
        XCTAssertEqual(activas.items.count, 1)
        XCTAssertEqual(activas.items.first?.status, .active)
    }
}

@MainActor
final class OfflineStatusTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        OfflineStatus.shared.reset()
    }

    override func tearDown() async throws {
        OfflineStatus.shared.reset()
        try await super.tearDown()
    }

    func testCacheEnciendeElAvisoConLaFechaMasVieja() {
        let viejo = Date().addingTimeInterval(-7200)
        let nuevo = Date().addingTimeInterval(-60)
        OfflineStatus.shared.noteCachedData(syncedAt: nuevo)
        OfflineStatus.shared.noteCachedData(syncedAt: viejo)

        XCTAssertTrue(OfflineStatus.shared.isServingCachedData)
        XCTAssertEqual(OfflineStatus.shared.cachedSince, viejo)
    }

    /// Un load MIXTO (algunos requests OK, otros desde cache) tiene que seguir
    /// avisando: parte de la pantalla es vieja.
    func testDatoFrescoNoBorraElAvisoDentroDeLaVentanaDeLoadMixto() {
        OfflineStatus.shared.noteCachedData(syncedAt: Date().addingTimeInterval(-60))
        OfflineStatus.shared.noteFreshData()
        XCTAssertTrue(OfflineStatus.shared.isServingCachedData)
    }

    func testResetApagaElAviso() {
        OfflineStatus.shared.noteCachedData(syncedAt: Date())
        OfflineStatus.shared.reset()
        XCTAssertFalse(OfflineStatus.shared.isServingCachedData)
        XCTAssertNil(OfflineStatus.shared.cachedSince)
    }

    func testSinCacheUnLoadFrescoDejaElAvisoApagado() {
        OfflineStatus.shared.noteFreshData()
        XCTAssertFalse(OfflineStatus.shared.isServingCachedData)
    }
}
