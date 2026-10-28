import Foundation

let homeNearbyWallLimit = 3
let homeWallZoomMeters = 400.0

func greetingText(name: String, hour: Int) -> String {
    let firstName = name.split(separator: " ").first.map(String.init) ?? name
    switch hour {
    case 5..<12: return "Good morning, \(firstName)"
    case 12..<17: return "Good afternoon, \(firstName)"
    default: return "Good evening, \(firstName)"
    }
}

func streakSummary(_ stats: UserStats, today: Int) -> String {
    let streak = displayedStreak(stats, today: today)
    if streak == 0 { return "No streak yet. Discover a wall to start one." }
    let streakText = streak == 1 ? "1 day streak" : "\(streak) day streak"
    if stats.streakFreezes == 0 { return streakText }
    let freezeText = stats.streakFreezes == 1 ? "1 freeze ready" : "\(stats.streakFreezes) freezes ready"
    return "\(streakText) · \(freezeText)"
}

func nearbyWallsSummary(count: Int, isOffline: Bool) -> String {
    let walls = count == 1 ? "1 wall" : "\(count) walls"
    if count == 0 { return isOffline ? "No saved walls within 1 km." : "No walls within 1 km yet." }
    return isOffline ? "\(walls) within 1 km (saved)" : "\(walls) within 1 km"
}

func ownedWallsSummary(count: Int) -> String {
    switch count {
    case 0: "You haven't placed a wall yet."
    case 1: "1 wall live"
    default: "\(count) walls live"
    }
}

func closestWalls(_ walls: [NearbyWall], limit: Int) -> [NearbyWall] {
    Array(walls.sorted { $0.distanceMeters < $1.distanceMeters }.prefix(max(0, limit)))
}

func shouldRefreshMapAfterPublish(oldCount: Int?, newCount: Int?) -> Bool {
    guard let oldCount, let newCount else { return false }
    return newCount > oldCount
}
