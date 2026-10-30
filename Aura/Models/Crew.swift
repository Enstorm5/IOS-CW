import Foundation

struct Crew: Equatable, Identifiable {
    var id: String
    var name: String
    var inviteCode: String
    var ownerID: String
    var memberCount: Int
}

struct CrewMember: Equatable, Identifiable {
    var id: String
    var displayName: String
    var avatarPreset: AvatarPreset
    var joinedAt: Date
    var showOnRankings = false
    var lifetimeXP = 0
    var weekStartDay = 0
    var weekDiscoveries = 0
}

// Ranked member
struct CrewRanking: Equatable, Identifiable {
    var rank: Int
    var member: CrewMember

    var id: String { member.id }
}

struct CrewInvite: Equatable, Identifiable {
    var code: String
    var crewID: String
    var crewName: String

    var id: String { code }
}

enum CrewLeavePlan: Equatable {
    case deleteCrew
    case leave(newOwnerID: String?)
}
