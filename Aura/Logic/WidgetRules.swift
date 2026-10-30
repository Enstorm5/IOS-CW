import Foundation

// App tabs
enum AppTab: Hashable {
    case map
    case quests
    case camera
    case crew
    case me
}

// Widget data
func widgetSnapshot(from stats: UserStats, questStates: [QuestState], accountID: String, now: Date) -> WidgetSnapshot {
    WidgetSnapshot(
        accountID: accountID,
        balance: stats.balance,
        streakDays: stats.streakDays,
        lastQualifiedDay: stats.lastQualifiedDay,
        questsDay: dayNumber(for: now),
        questsDone: questStates.filter { $0 == .claimed }.count,
        questsTotal: questStates.count,
        updatedAt: now,
        streakFreezes: stats.streakFreezes
    )
}

// Deep links
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
