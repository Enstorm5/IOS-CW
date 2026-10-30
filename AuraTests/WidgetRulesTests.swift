import Testing
import Foundation
@testable import Aura

@MainActor
struct WidgetRulesTests {
    let today = 20_400

    func snapshot(streak: Int = 3, lastQualified: Int, questsDay: Int, done: Int, total: Int = 2) -> WidgetSnapshot {
        WidgetSnapshot(accountID: "u1", balance: 120, streakDays: streak, lastQualifiedDay: lastQualified, questsDay: questsDay, questsDone: done, questsTotal: total, updatedAt: Date(timeIntervalSince1970: 0))
    }

    @Test func widgetDayMatchesTheAppDay() {
        for seconds in [0.0, 1_000_000, 1_761_600_000, 1_761_680_999, 1_761_681_000] {
            let date = Date(timeIntervalSince1970: seconds)
            #expect(widgetDayNumber(for: date) == dayNumber(for: date))
        }
    }

    @Test func nextDayStartsAtColomboMidnight() {
        let midnight = Date(timeIntervalSince1970: Double(today * secondsPerDay - colomboUTCOffsetSeconds))
        #expect(startOfNextWidgetDay(after: midnight.addingTimeInterval(-1)) == midnight)
        #expect(startOfNextWidgetDay(after: midnight) == midnight.addingTimeInterval(Double(secondsPerDay)))
    }

    @Test func snapshotComesFromConfirmedStatsAndQuestStates() {
        let stats = UserStats(balance: 120, streakDays: 3, lastQualifiedDay: today)
        let now = Date(timeIntervalSince1970: Double(today * secondsPerDay))
        let made = widgetSnapshot(from: stats, questStates: [.claimed, .inProgress(0)], accountID: "u1", now: now)
        #expect(made == WidgetSnapshot(accountID: "u1", balance: 120, streakDays: 3, lastQualifiedDay: today, questsDay: dayNumber(for: now), questsDone: 1, questsTotal: 2, updatedAt: now, streakFreezes: 0))
    }

    @Test func oldSnapshotsResetForANewDay() {
        let fresh = snapshot(lastQualified: today, questsDay: today, done: 1)
        #expect(widgetStreak(fresh, today: today) == 3)
        #expect(widgetQuestText(fresh, today: today) == "1 of 2 quests done")

        #expect(widgetStreak(fresh, today: today + 1) == 3)
        #expect(widgetQuestText(fresh, today: today + 1) == "0 of 2 quests done")
        #expect(widgetStreak(fresh, today: today + 2) == 0)
    }

    @Test func questTextShowsAllDone() {
        #expect(widgetQuestText(snapshot(lastQualified: today, questsDay: today, done: 2), today: today) == "All quests done")
        #expect(widgetQuestText(snapshot(lastQualified: today, questsDay: today, done: 5), today: today) == "All quests done")
        #expect(widgetQuestText(snapshot(lastQualified: today, questsDay: today, done: 0, total: 0), today: today) == "0 of 0 quests done")
    }

    @Test func snapshotRoundTripsAndRejectsJunk() {
        let original = snapshot(lastQualified: today, questsDay: today, done: 1)
        #expect(decodeWidgetSnapshot(encodeWidgetSnapshot(original)) == original)
        #expect(decodeWidgetSnapshot(Data("nope".utf8)) == nil)
        #expect(decodeWidgetSnapshot(nil) == nil)
    }

    @Test func onlyTheSignedInAccountKeepsItsSnapshot() {
        let stored = snapshot(lastQualified: today, questsDay: today, done: 1)
        #expect(shouldKeepWidgetSnapshot(stored, signedInAccountID: "u1"))
        #expect(!shouldKeepWidgetSnapshot(stored, signedInAccountID: "u2"))
        #expect(!shouldKeepWidgetSnapshot(stored, signedInAccountID: nil))
        #expect(!shouldKeepWidgetSnapshot(nil, signedInAccountID: "u1"))
    }

    @Test func appGroupFollowsTheBundleIDForTheAppAndTheWidget() {
        #expect(appGroupID(forBundleID: "l.Aura") == "group.l.Aura")
        #expect(appGroupID(forBundleID: "l.Aura.AuraWidget") == "group.l.Aura")
        #expect(appGroupID(forBundleID: "com.example.Aura.AuraWidget") == "group.com.example.Aura")
        #expect(appGroupID(forBundleID: "com.example.Aura") == appGroupID(forBundleID: "com.example.Aura.AuraWidget"))
    }

    @Test func deepLinksPickATab() {
        #expect(appTab(forDeepLink: URL(string: "aura://quests")!) == .quests)
        #expect(appTab(forDeepLink: URL(string: "aura://crew")!) == .crew)
        #expect(appTab(forDeepLink: URL(string: "aura://nowhere")!) == nil)
        #expect(appTab(forDeepLink: URL(string: "https://quests")!) == nil)
    }
}
