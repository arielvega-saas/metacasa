import Foundation

struct UserEntitlement: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(userId.uuidString)_\(entitlement)" }
    let userId: UUID
    let entitlement: String
    var isActive: Bool
    var expiresAt: Date?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case entitlement
        case isActive = "is_active"
        case expiresAt = "expires_at"
        case updatedAt = "updated_at"
    }

    /// Nombres canónicos de entitlements. Deben coincidir con RevenueCat.
    enum Name {
        static let premium = "premium"
        static let pro = "pro"
    }
}

struct Subscription: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    var revenuecatUserId: String?
    var productId: String
    var entitlementId: String
    var store: SubscriptionStore
    var environment: Environment
    var status: SubscriptionStatus
    var periodType: PeriodKind?
    var purchasedAt: Date?
    var renewedAt: Date?
    var expiresAt: Date?
    var canceledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case revenuecatUserId = "revenuecat_user_id"
        case productId = "product_id"
        case entitlementId = "entitlement_id"
        case store
        case environment
        case status
        case periodType = "period_type"
        case purchasedAt = "purchased_at"
        case renewedAt = "renewed_at"
        case expiresAt = "expires_at"
        case canceledAt = "canceled_at"
    }
}

enum SubscriptionStore: String, Codable, Hashable, Sendable {
    case appStore = "app_store"
    case playStore = "play_store"
    case stripe
    case promotional
}

enum Environment: String, Codable, Hashable, Sendable {
    case production
    case sandbox
}

enum SubscriptionStatus: String, Codable, Hashable, Sendable {
    case active, trialing
    case gracePeriod = "grace_period"
    case canceled, expired, paused
    case billingIssue = "billing_issue"
}

enum PeriodKind: String, Codable, Hashable, Sendable {
    case normal, intro, trial
}
