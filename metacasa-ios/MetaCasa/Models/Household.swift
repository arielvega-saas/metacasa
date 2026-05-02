import Foundation

struct Household: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    let createdBy: UUID
    var timezone: String
    var defaultCurrency: String
    let createdAt: Date
    var updatedAt: Date
    var strategy: HouseholdStrategy?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case timezone
        case defaultCurrency = "default_currency"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case strategy
    }
}

/// Configuración waterfall del hogar. Port de la lógica web
/// (App.jsx:6245-6307).
struct HouseholdStrategy: Codable, Hashable, Sendable {
    /// Porcentaje del remanente que va automáticamente a ahorro (0-100).
    var savingsPct: Decimal = 10
    /// Porcentaje del remanente que va a inversión (0-100).
    var investmentPct: Decimal = 0
    /// Modo de distribución del remanente entre cuentas personales.
    var distributionMode: DistributionMode = .equal
    /// Allocations custom por cuenta (usado cuando mode == .custom).
    var customAllocations: [String: Decimal] = [:]
    /// Flags para incluir/excluir cada tipo de deducción del waterfall.
    var includeBillsInWaterfall: Bool = true
    var includeInstallmentsInWaterfall: Bool = true
    var includeDebtPaymentsInWaterfall: Bool = true

    enum CodingKeys: String, CodingKey {
        case savingsPct = "savings_pct"
        case investmentPct = "investment_pct"
        case distributionMode = "distribution_mode"
        case customAllocations = "custom_allocations"
        case includeBillsInWaterfall = "include_bills_in_waterfall"
        case includeInstallmentsInWaterfall = "include_installments_in_waterfall"
        case includeDebtPaymentsInWaterfall = "include_debt_payments_in_waterfall"
    }

    enum DistributionMode: String, Codable, Hashable, Sendable, CaseIterable {
        case equal, proportional, custom
        var label: String {
            switch self {
            case .equal:        return "Equitativa"
            case .proportional: return "Proporcional"
            case .custom:       return "Personalizada"
            }
        }
    }

    static let `default` = HouseholdStrategy()
}

struct HouseholdMember: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(householdId.uuidString)_\(userId.uuidString)" }
    let householdId: UUID
    let userId: UUID
    var role: MemberRole
    var displayName: String?
    let joinedAt: Date
    let invitedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case userId = "user_id"
        case role
        case displayName = "display_name"
        case joinedAt = "joined_at"
        case invitedBy = "invited_by"
    }
}

enum MemberRole: String, Codable, Hashable, Sendable, CaseIterable {
    case owner, admin, member, viewer

    var label: String {
        switch self {
        case .owner: "Propietario"
        case .admin: "Administrador"
        case .member: "Miembro"
        case .viewer: "Solo lectura"
        }
    }

    var canInvite: Bool {
        self == .owner || self == .admin
    }
}

struct HouseholdInvitation: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let householdId: UUID
    var email: String
    var role: MemberRole
    var inviteToken: String
    let invitedBy: UUID
    var expiresAt: Date
    var acceptedAt: Date?
    var acceptedBy: UUID?
    var status: InvitationStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case email
        case role
        case inviteToken = "invite_token"
        case invitedBy = "invited_by"
        case expiresAt = "expires_at"
        case acceptedAt = "accepted_at"
        case acceptedBy = "accepted_by"
        case status
        case createdAt = "created_at"
    }
}

enum InvitationStatus: String, Codable, Hashable, Sendable {
    case pending, accepted, expired, revoked
}
