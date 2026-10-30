import Testing
import Foundation
@testable import Aura

@MainActor
struct QuestRemindersTests {
    let today = 20_400

    func moment(day: Int, hour: Int, minute: Int = 0) -> Date {
        colomboDate(day: day, hour: hour).addingTimeInterval(Double(minute * 60))
    }

    @Test func colomboTimesAreFixedToTheLocalDay() {
        let nineAM = colomboDate(day: today, hour: 9)
        #expect(dayNumber(for: nineAM) == today)
        #expect(nineAM.timeIntervalSince1970 == Double(today * secondsPerDay - colomboUTCOffsetSeconds + 9 * 3_600))
        #expect(dayNumber(for: colomboDate(day: today, hour: 19)) == today)
    }

    @Test func morningReminderNamesTodaysQuestsAndTotalPoints() {
        let reminder = morningReminder(day: today)
        #expect(reminder.id == "quest-morning-20400")
        #expect(reminder.title == "New quests today")
        #expect(reminder.body == "Read 3 walls · Write on a wall. Up to +45 pts.")
        #expect(reminder.fireDate == colomboDate(day: today, hour: 9))
    }

    @Test func upcomingEveningReminderListsThatDaysQuests() {
        let reminder = upcomingEveningReminder(day: today + 1)
        #expect(reminder.id == "quest-evening-20401")
        #expect(reminder.body == "Read 5 walls · Draw on a wall. Finish them before midnight.")
        #expect(reminder.fireDate == colomboDate(day: today + 1, hour: 19))
    }

    @Test func todaysEveningReminderDependsOnQuestProgress() {
        let quiet = UserStats(streakDays: 0)
        #expect(todaysEveningReminder(day: today, states: [.claimed, .claimed], stats: quiet) == nil)

        let ready = todaysEveningReminder(day: today, states: [.readyToClaim, .claimed], stats: quiet)
        #expect(ready?.title == "Claim your quest points")
        #expect(ready?.body == "1 quest is ready to claim.")

        let todo = todaysEveningReminder(day: today, states: [.inProgress(1), .inProgress(0)], stats: quiet)
        #expect(todo?.title == "Quests are waiting")
        #expect(todo?.body == "2 quests still to do.")

        let both = todaysEveningReminder(day: today, states: [.readyToClaim, .inProgress(0)], stats: quiet)
        #expect(both?.body == "1 quest is ready to claim. 1 quest still to do.")
    }

    @Test func streakAtRiskAddsAWarningEvenWhenQuestsAreDone() {
        let stats = UserStats(streakDays: 4, lastQualifiedDay: today - 1)
        #expect(isStreakAtRisk(stats, today: today))
        let reminder = todaysEveningReminder(day: today, states: [.claimed, .claimed], stats: stats)
        #expect(reminder?.body == "Your 4 day streak ends tonight. Read one wall to keep it.")

        let safe = UserStats(streakDays: 4, lastQualifiedDay: today)
        #expect(!isStreakAtRisk(safe, today: today))
        #expect(!isStreakAtRisk(UserStats(streakDays: 0, lastQualifiedDay: 0), today: today))
        #expect(!isStreakAtRisk(UserStats(streakDays: 4, lastQualifiedDay: today - 3), today: today))
    }

    @Test func planCoversSevenDaysOfMorningsAndEvenings() {
        let now = moment(day: today, hour: 6)
        let planned = plannedQuestReminders(now: now, stats: UserStats(), todayStates: [.inProgress(0), .inProgress(0)])
        #expect(planned.count == 14)
        #expect(Set(planned.map(\.id)).count == 14)
        #expect(planned == planned.sorted { $0.fireDate < $1.fireDate })
        #expect(planned.first?.id == "quest-morning-20400")
    }

    @Test func pastRemindersAreLeftOut() {
        let afternoon = moment(day: today, hour: 15)
        let planned = plannedQuestReminders(now: afternoon, stats: UserStats(), todayStates: [.inProgress(0), .inProgress(0)])
        #expect(!planned.map(\.id).contains("quest-morning-20400"))
        #expect(planned.map(\.id).contains("quest-evening-20400"))

        let night = moment(day: today, hour: 22)
        let late = plannedQuestReminders(now: night, stats: UserStats(), todayStates: [.inProgress(0), .inProgress(0)])
        #expect(!late.map(\.id).contains("quest-evening-20400"))
        #expect(late.first?.id == "quest-morning-20401")
    }

    @Test func aReminderTooCloseToNowIsSkipped() {
        let almostNine = moment(day: today, hour: 9).addingTimeInterval(-30)
        let planned = plannedQuestReminders(now: almostNine, stats: UserStats(), todayStates: [])
        #expect(!planned.map(\.id).contains("quest-morning-20400"))
    }

    @Test func finishedQuestsRemoveTodaysEveningReminder() {
        let now = moment(day: today, hour: 10)
        let planned = plannedQuestReminders(now: now, stats: UserStats(), todayStates: [.claimed, .claimed])
        #expect(!planned.map(\.id).contains("quest-evening-20400"))
        #expect(planned.map(\.id).contains("quest-evening-20401"))
    }

    @Test func allReminderIDsUseThePrefixSoTheyCanBeCancelled() {
        let planned = plannedQuestReminders(now: moment(day: today, hour: 6), stats: UserStats(), todayStates: [.inProgress(0)])
        #expect(planned.allSatisfy { $0.id.hasPrefix(questReminderPrefix) })
    }

    @Test func deniedMessageAppearsOnlyWhenEnabledButBlocked() {
        #expect(notificationDeniedMessage(isEnabled: true, isAllowedBySystem: false) != nil)
        #expect(notificationDeniedMessage(isEnabled: true, isAllowedBySystem: true) == nil)
        #expect(notificationDeniedMessage(isEnabled: false, isAllowedBySystem: false) == nil)
    }
}
