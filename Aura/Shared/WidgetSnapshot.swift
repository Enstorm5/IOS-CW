import Foundation

nonisolated struct WidgetSnapshot: Codable, Equatable {
    var accountID: String
    var balance: Int
    var streakDays: Int
    var lastQualifiedDay: Int
    var questDay: Int
    var questProgress: Int
    var questTarget: Int
    var questClaimedDay: Int
    var updatedAt: Date
    var streakFreezes: Int? = nil
}

nonisolated enum WidgetConfig {
    static let appGroupID = "group.l.Aura"
    static let snapshotKey = "widgetSnapshot"
    static let questsLink = "aura://quests"
    static let utcOffsetSeconds = 19_800
    static let secondsPerDay = 86_400
}

nonisolated func widgetDayNumber(for date: Date) -> Int {
    Int(((date.timeIntervalSince1970 + Double(WidgetConfig.utcOffsetSeconds)) / Double(WidgetConfig.secondsPerDay)).rounded(.down))
}

nonisolated func startOfNextWidgetDay(after date: Date) -> Date {
    let nextDay = widgetDayNumber(for: date) + 1
    return Date(timeIntervalSince1970: Double(nextDay * WidgetConfig.secondsPerDay - WidgetConfig.utcOffsetSeconds))
}

nonisolated func widgetStreak(_ snapshot: WidgetSnapshot, today: Int) -> Int {
    let isFrozen = snapshot.lastQualifiedDay == today - 2 && (snapshot.streakFreezes ?? 0) > 0 && snapshot.streakDays > 0
    return snapshot.lastQualifiedDay >= today - 1 || isFrozen ? snapshot.streakDays : 0
}

nonisolated func widgetQuestProgress(_ snapshot: WidgetSnapshot, today: Int) -> Int {
    snapshot.questDay == today ? min(snapshot.questProgress, snapshot.questTarget) : 0
}

nonisolated func isWidgetQuestClaimed(_ snapshot: WidgetSnapshot, today: Int) -> Bool {
    snapshot.questClaimedDay == today
}

nonisolated func widgetQuestText(_ snapshot: WidgetSnapshot, today: Int) -> String {
    if isWidgetQuestClaimed(snapshot, today: today) { return "Quest done" }
    let progress = widgetQuestProgress(snapshot, today: today)
    if progress >= snapshot.questTarget { return "Claim your quest" }
    return "\(progress) of \(snapshot.questTarget) walls"
}

nonisolated func encodeWidgetSnapshot(_ snapshot: WidgetSnapshot) -> Data? {
    try? JSONEncoder().encode(snapshot)
}

nonisolated func decodeWidgetSnapshot(_ data: Data?) -> WidgetSnapshot? {
    guard let data else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
}
