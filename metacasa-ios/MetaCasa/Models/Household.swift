import Foundation

struct Household: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    let createdBy: UUID
    var timezone: String
    var defaultCurrency: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case timezone
        case defaultCurrency = "default_currency"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
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
