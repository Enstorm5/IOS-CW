import Foundation

enum AppTab: Hashable {
    case map
    case quests
    case camera
    case crew
    case me
}

func widgetSnapshot(from stats: UserStats, accountID: String, now: Date) -> WidgetSnapshot {
    WidgetSnapshot(
        accountID: accountID,
        balance: stats.balance,
        streakDays: stats.streakDays,
        lastQualifiedDay: stats.lastQualifiedDay,
        questDay: stats.dailyDay,
        questProgress: stats.dailyDiscoveries,
        questTarget: dailyQuestTarget,
        questClaimedDay: claimedQuestDay(lastClaimID: stats.lastClaimID),
        updatedAt: now,
        streakFreezes: stats.streakFreezes
    )
}

func claimedQuestDay(lastClaimID: String) -> Int {
    guard lastClaimID.hasSuffix("_readFive"),
          let dayText = lastClaimID.split(separator: "_").first else { return 0 }
    return Int(dayText) ?? 0
}

func appTab(forDeepLink url: URL) -> AppTab? {
    guard url.scheme == "aura" else { return nil }
    switch url.host() {
    case "quests": return .quests
    case "map": return .map
    case "crew": return .crew
    default: return nil
    }
}

func shouldKeepWidgetSnapshot(_ snapshot: WidgetSnapshot?, signedInAccountID: String?) -> Bool {
    guard let snapshot, let signedInAccountID else { return false }
    return snapshot.accountID == signedInAccountID
}
