import Foundation

// Reminder times
let questReminderMorningHour = 9
let questReminderEveningHour = 19
let questReminderDaysAhead = 6
let questReminderMinimumLeadSeconds = 60.0
let questReminderPrefix = "quest-"

struct PlannedNotification: Equatable {
    let id: String
    let fireDate: Date
    let title: String
    let body: String
}

// Colombo time
func colomboDate(day: Int, hour: Int) -> Date {
    Date(timeIntervalSince1970: Double(day * secondsPerDay - colomboUTCOffsetSeconds + hour * 3_600))
}

func questNamesText(_ quests: [Quest]) -> String {
    quests.map(\.title).joined(separator: " · ")
}

// Morning note
func morningReminder(day: Int) -> PlannedNotification {
    let quests = questsForDay(day)
    let points = quests.reduce(0) { $0 + $1.reward }
    return PlannedNotification(
        id: "\(questReminderPrefix)morning-\(day)",
        fireDate: colomboDate(day: day, hour: questReminderMorningHour),
        title: "New quests today",
        body: "\(questNamesText(quests)). Up to +\(points) pts."
    )
}

func upcomingEveningReminder(day: Int) -> PlannedNotification {
    let quests = questsForDay(day)
    return PlannedNotification(
        id: "\(questReminderPrefix)evening-\(day)",
        fireDate: colomboDate(day: day, hour: questReminderEveningHour),
        title: "Today's quests are waiting",
        body: "\(questNamesText(quests)). Finish them before midnight."
    )
}

func isStreakAtRisk(_ stats: UserStats, today: Int) -> Bool {
    displayedStreak(stats, today: today) > 0 && stats.lastQualifiedDay < today
}

func todaysEveningReminder(day: Int, states: [QuestState], stats: UserStats) -> PlannedNotification? {
    let ready = states.filter { $0 == .readyToClaim }.count
    let toDo = states.filter { if case .inProgress = $0 { true } else { false } }.count
    let streakAtRisk = isStreakAtRisk(stats, today: day)
    if ready == 0 && toDo == 0 && !streakAtRisk { return nil }

    var parts: [String] = []
    if ready > 0 { parts.append(ready == 1 ? "1 quest is ready to claim." : "\(ready) quests are ready to claim.") }
    if toDo > 0 { parts.append(toDo == 1 ? "1 quest still to do." : "\(toDo) quests still to do.") }
    if streakAtRisk { parts.append("Your \(displayedStreak(stats, today: day)) day streak ends tonight. Read one wall to keep it.") }

    return PlannedNotification(
        id: "\(questReminderPrefix)evening-\(day)",
        fireDate: colomboDate(day: day, hour: questReminderEveningHour),
        title: ready > 0 ? "Claim your quest points" : "Quests are waiting",
        body: parts.joined(separator: " ")
    )
}

func plannedQuestReminders(now: Date, stats: UserStats, todayStates: [QuestState]) -> [PlannedNotification] {
    let today = dayNumber(for: now)
    var planned: [PlannedNotification] = []
    for offset in 0...questReminderDaysAhead {
        let day = today + offset
        planned.append(morningReminder(day: day))
        if offset == 0 {
            if let evening = todaysEveningReminder(day: day, states: todayStates, stats: stats) {
                planned.append(evening)
            }
        } else {
            planned.append(upcomingEveningReminder(day: day))
        }
    }
    return planned
        .filter { $0.fireDate.timeIntervalSince(now) >= questReminderMinimumLeadSeconds }
        .sorted { $0.fireDate < $1.fireDate }
}

func notificationDeniedMessage(isEnabled: Bool, isAllowedBySystem: Bool) -> String? {
    if isEnabled && !isAllowedBySystem {
        return "Notifications are off for Aura in iOS Settings, so no reminders will appear."
    }
    return nil
}
