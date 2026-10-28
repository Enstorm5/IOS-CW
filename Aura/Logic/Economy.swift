import Foundation

let discoveryRewardPoints = 10
let dailyQuestRewardPoints = 40
let dailyQuestTarget = 5
let colomboUTCOffsetSeconds = 19_800
let secondsPerDay = 86_400
let publicWallCost = 50
let levelThresholds = [0, 100, 250, 450, 700, 1_000, 1_400, 1_900, 2_500, 3_200, 4_000]

func dayNumber(for date: Date, utcOffsetSeconds: Int = colomboUTCOffsetSeconds) -> Int {
    Int(((date.timeIntervalSince1970 + Double(utcOffsetSeconds)) / Double(secondsPerDay)).rounded(.down))
}

func streakAfterQualifying(streakDays: Int, lastQualifiedDay: Int, today: Int) -> Int {
    if lastQualifiedDay == today { return streakDays }
    if lastQualifiedDay == today - 1 { return streakDays + 1 }
    return 1
}

func streakQualifyingOutcome(streakDays: Int, lastQualifiedDay: Int, today: Int, freezes: Int) -> (streak: Int, usedFreeze: Bool) {
    if lastQualifiedDay == today - 2 && freezes > 0 && streakDays > 0 {
        return (streakDays + 1, true)
    }
    return (streakAfterQualifying(streakDays: streakDays, lastQualifiedDay: lastQualifiedDay, today: today), false)
}

func isStreakProtectedByFreeze(_ stats: UserStats, today: Int) -> Bool {
    stats.lastQualifiedDay == today - 2 && stats.streakFreezes > 0 && stats.streakDays > 0
}

func displayedStreak(_ stats: UserStats, today: Int) -> Int {
    if stats.lastQualifiedDay >= today - 1 || isStreakProtectedByFreeze(stats, today: today) {
        return stats.streakDays
    }
    return 0
}

func weekStartDay(forDay day: Int) -> Int {
    day - ((day + 3) % 7)
}

func statsAfterDiscovery(_ stats: UserStats, wallID: String, today: Int) -> UserStats {
    var updated = stats
    updated.balance += discoveryRewardPoints
    updated.lifetimeXP += discoveryRewardPoints
    updated.discoveryCount += 1
    updated.dailyDiscoveries = stats.dailyDay == today ? stats.dailyDiscoveries + 1 : 1
    updated.dailyDay = today
    let weekStart = weekStartDay(forDay: today)
    updated.weekDiscoveries = stats.weekStartDay == weekStart ? stats.weekDiscoveries + 1 : 1
    updated.weekStartDay = weekStart
    let outcome = streakQualifyingOutcome(streakDays: stats.streakDays, lastQualifiedDay: stats.lastQualifiedDay, today: today, freezes: stats.streakFreezes)
    updated.streakDays = outcome.streak
    if outcome.usedFreeze {
        updated.streakFreezes = stats.streakFreezes - 1
    }
    updated.longestStreak = max(stats.longestStreak, updated.streakDays)
    updated.lastQualifiedDay = today
    updated.lastDiscoveryWallID = wallID
    return updated
}

func dailyQuestClaimID(today: Int) -> String {
    "\(today)_readFive"
}

func dailyQuestProgress(_ stats: UserStats, today: Int) -> Int {
    stats.dailyDay == today ? min(stats.dailyDiscoveries, dailyQuestTarget) : 0
}

func isDailyQuestClaimed(_ stats: UserStats, today: Int) -> Bool {
    stats.lastClaimID == dailyQuestClaimID(today: today)
}

func canClaimDailyQuest(_ stats: UserStats, today: Int) -> Bool {
    stats.dailyDay == today && stats.dailyDiscoveries >= dailyQuestTarget && !isDailyQuestClaimed(stats, today: today)
}

func statsAfterDailyQuestClaim(_ stats: UserStats, today: Int) -> UserStats {
    var updated = stats
    updated.balance += dailyQuestRewardPoints
    updated.lifetimeXP += dailyQuestRewardPoints
    updated.questsClaimed += 1
    updated.lastClaimID = dailyQuestClaimID(today: today)
    return updated
}

func statsAfterWallPublish(_ stats: UserStats, wallID: String) -> UserStats {
    var updated = stats
    updated.balance -= publicWallCost
    updated.wallsPublished += 1
    updated.lastPublishedWallID = wallID
    return updated
}

func publishCostMessage(balance: Int) -> String {
    if canAfford(balance: balance, cost: publicWallCost) {
        return "Publishing costs \(formattedPoints(publicWallCost)). You have \(formattedPoints(balance))."
    }
    return "Publishing costs \(formattedPoints(publicWallCost)). You have \(formattedPoints(balance)). Discover walls and claim quests to earn more."
}

func level(forXP xp: Int) -> Int {
    (levelThresholds.lastIndex { xp >= $0 } ?? 0) + 1
}

func levelProgress(forXP xp: Int) -> (current: Int, needed: Int)? {
    let index = level(forXP: xp) - 1
    guard index + 1 < levelThresholds.count else { return nil }
    return (xp - levelThresholds[index], levelThresholds[index + 1] - levelThresholds[index])
}

func canAfford(balance: Int, cost: Int) -> Bool {
    balance >= 0 && cost >= 0 && balance >= cost
}

func formattedPoints(_ points: Int) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.numberStyle = .decimal
    return "\(formatter.string(from: NSNumber(value: points)) ?? String(points)) pts"
}

func badges(for stats: UserStats) -> [Badge] {
    [
        Badge(id: "first-find", title: "First find", detail: "Discover your first wall", progress: min(stats.discoveryCount, 1), target: 1),
        Badge(id: "wall-hunter", title: "Wall hunter", detail: "Discover 10 walls", progress: min(stats.discoveryCount, 10), target: 10),
        Badge(id: "trailblazer", title: "Trailblazer", detail: "Discover 25 walls", progress: min(stats.discoveryCount, 25), target: 25),
        Badge(id: "on-a-roll", title: "On a roll", detail: "Reach a 3 day streak", progress: min(stats.longestStreak, 3), target: 3),
        Badge(id: "committed", title: "Committed", detail: "Reach a 7 day streak", progress: min(stats.longestStreak, 7), target: 7),
        Badge(id: "quest-starter", title: "Quest starter", detail: "Claim a daily quest", progress: min(stats.questsClaimed, 1), target: 1),
        Badge(id: "first-wall", title: "First wall", detail: "Publish your own wall", progress: min(stats.wallsPublished, 1), target: 1),
    ]
}

func userStats(fields: [String: Any]) -> UserStats {
    UserStats(
        balance: fields["balance"] as? Int ?? 0,
        lifetimeXP: fields["lifetimeXP"] as? Int ?? 0,
        discoveryCount: fields["discoveryCount"] as? Int ?? 0,
        streakDays: fields["streakDays"] as? Int ?? 0,
        longestStreak: fields["longestStreak"] as? Int ?? 0,
        lastQualifiedDay: fields["lastQualifiedDay"] as? Int ?? 0,
        dailyDay: fields["dailyDay"] as? Int ?? 0,
        dailyDiscoveries: fields["dailyDiscoveries"] as? Int ?? 0,
        questsClaimed: fields["questsClaimed"] as? Int ?? 0,
        lastDiscoveryWallID: fields["lastDiscoveryWallID"] as? String ?? "",
        lastClaimID: fields["lastClaimID"] as? String ?? "",
        wallsPublished: fields["wallsPublished"] as? Int ?? 0,
        lastPublishedWallID: fields["lastPublishedWallID"] as? String ?? "",
        weekStartDay: fields["weekStartDay"] as? Int ?? 0,
        weekDiscoveries: fields["weekDiscoveries"] as? Int ?? 0,
        streakFreezes: fields["streakFreezes"] as? Int ?? 0,
        lastPurchaseID: fields["lastPurchaseID"] as? String ?? ""
    )
}

func firestoreFields(for stats: UserStats) -> [String: Any] {
    [
        "balance": stats.balance,
        "lifetimeXP": stats.lifetimeXP,
        "discoveryCount": stats.discoveryCount,
        "streakDays": stats.streakDays,
        "longestStreak": stats.longestStreak,
        "lastQualifiedDay": stats.lastQualifiedDay,
        "dailyDay": stats.dailyDay,
        "dailyDiscoveries": stats.dailyDiscoveries,
        "questsClaimed": stats.questsClaimed,
        "lastDiscoveryWallID": stats.lastDiscoveryWallID,
        "lastClaimID": stats.lastClaimID,
        "wallsPublished": stats.wallsPublished,
        "lastPublishedWallID": stats.lastPublishedWallID,
        "weekStartDay": stats.weekStartDay,
        "weekDiscoveries": stats.weekDiscoveries,
        "streakFreezes": stats.streakFreezes,
        "lastPurchaseID": stats.lastPurchaseID,
    ]
}
