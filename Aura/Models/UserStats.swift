import Foundation

struct UserStats: Equatable {
    var balance = 0
    var lifetimeXP = 0
    var discoveryCount = 0
    var streakDays = 0
    var longestStreak = 0
    var lastQualifiedDay = 0
    var dailyDay = 0
    var dailyDiscoveries = 0
    var questsClaimed = 0
    var lastDiscoveryWallID = ""
    var lastClaimID = ""
    var wallsPublished = 0
    var lastPublishedWallID = ""
}

struct Badge: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let progress: Int
    let target: Int

    var isEarned: Bool { progress >= target }
}

enum DiscoveryOutcome: Equatable {
    case awarded(UserStats)
    case alreadyDiscovered
}
