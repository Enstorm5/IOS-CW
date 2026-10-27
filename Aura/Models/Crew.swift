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
