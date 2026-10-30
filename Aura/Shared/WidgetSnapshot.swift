import Foundation

nonisolated struct WidgetSnapshot: Codable, Equatable {
    var accountID: String
    var balance: Int
    var streakDays: Int
    var lastQualifiedDay: Int
    var questsDay: Int
    var questsDone: Int
    var questsTotal: Int
    var updatedAt: Date
    var streakFreezes: Int? = nil
}

nonisolated enum WidgetConfig {
    static var appGroupID: String { groupIdentifier(forBundleID: Bundle.main.bundleIdentifier ?? "") }
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

// Streak display
nonisolated func widgetStreak(_ snapshot: WidgetSnapshot, today: Int) -> Int {
    let isFrozen = snapshot.lastQualifiedDay == today - 2 && (snapshot.streakFreezes ?? 0) > 0 && snapshot.streakDays > 0
    return snapshot.lastQualifiedDay >= today - 1 || isFrozen ? snapshot.streakDays : 0
}

nonisolated func widgetQuestProgress(_ snapshot: WidgetSnapshot, today: Int) -> Int {
    snapshot.questsDay == today ? min(snapshot.questsDone, snapshot.questsTotal) : 0
}

nonisolated func widgetQuestsAllDone(_ snapshot: WidgetSnapshot, today: Int) -> Bool {
    snapshot.questsTotal > 0 && widgetQuestProgress(snapshot, today: today) >= snapshot.questsTotal
}

nonisolated func widgetQuestText(_ snapshot: WidgetSnapshot, today: Int) -> String {
    if widgetQuestsAllDone(snapshot, today: today) { return "All quests done" }
    return "\(widgetQuestProgress(snapshot, today: today)) of \(snapshot.questsTotal) quests done"
}

nonisolated func encodeWidgetSnapshot(_ snapshot: WidgetSnapshot) -> Data? {
    try? JSONEncoder().encode(snapshot)
}

nonisolated func decodeWidgetSnapshot(_ data: Data?) -> WidgetSnapshot? {
    guard let data else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
}

// App group from bundle ID
nonisolated func groupIdentifier(forBundleID bundleID: String) -> String {
    let widgetSuffix = ".AuraWidget"
    let appID = bundleID.hasSuffix(widgetSuffix) ? String(bundleID.dropLast(widgetSuffix.count)) : bundleID
    return "group.\(appID)"
}
