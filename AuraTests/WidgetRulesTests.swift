import Testing
import Foundation
@testable import Aura

@MainActor
struct WidgetRulesTests {
    let today = 20_400

    func snapshot(streak: Int = 3, lastQualified: Int, questDay: Int, progress: Int, claimedDay: Int = 0) -> WidgetSnapshot {
        WidgetSnapshot(accountID: "u1", balance: 120, streakDays: streak, lastQualifiedDay: lastQualified, questDay: questDay, questProgress: progress, questTarget: 5, questClaimedDay: claimedDay, updatedAt: Date(timeIntervalSince1970: 0))
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

    @Test func snapshotComesFromConfirmedStats() {
        let stats = UserStats(balance: 120, streakDays: 3, lastQualifiedDay: today, dailyDay: today, dailyDiscoveries: 2, lastClaimID: "\(today - 1)_readFive")
        let now = Date(timeIntervalSince1970: 50)
        let made = widgetSnapshot(from: stats, accountID: "u1", now: now)
        #expect(made == WidgetSnapshot(accountID: "u1", balance: 120, streakDays: 3, lastQualifiedDay: today, questDay: today, questProgress: 2, questTarget: 5, questClaimedDay: today - 1, updatedAt: now))
    }

    @Test func claimedDayIsReadFromTheClaimID() {
        #expect(claimedQuestDay(lastClaimID: "20400_readFive") == 20_400)
        #expect(claimedQuestDay(lastClaimID: "") == 0)
        #expect(claimedQuestDay(lastClaimID: "abc_readFive") == 0)
        #expect(claimedQuestDay(lastClaimID: "20400_other") == 0)
    }

    @Test func oldSnapshotsResetForANewDay() {
        let fresh = snapshot(lastQualified: today, questDay: today, progress: 3)
        #expect(widgetStreak(fresh, today: today) == 3)
        #expect(widgetQuestText(fresh, today: today) == "3 of 5 walls")

        #expect(widgetStreak(fresh, today: today + 1) == 3)
        #expect(widgetQuestText(fresh, today: today + 1) == "0 of 5 walls")
        #expect(widgetStreak(fresh, today: today + 2) == 0)
    }

    @Test func questTextShowsReadyAndDone() {
        #expect(widgetQuestText(snapshot(lastQualified: today, questDay: today, progress: 7), today: today) == "Claim your quest")
        #expect(widgetQuestText(snapshot(lastQualified: today, questDay: today, progress: 5, claimedDay: today), today: today) == "Quest done")
    }

    @Test func snapshotRoundTripsAndRejectsJunk() {
        let original = snapshot(lastQualified: today, questDay: today, progress: 1)
        #expect(decodeWidgetSnapshot(encodeWidgetSnapshot(original)) == original)
        #expect(decodeWidgetSnapshot(Data("nope".utf8)) == nil)
        #expect(decodeWidgetSnapshot(nil) == nil)
    }

    @Test func onlyTheSignedInAccountKeepsItsSnapshot() {
        let stored = snapshot(lastQualified: today, questDay: today, progress: 1)
        #expect(shouldKeepWidgetSnapshot(stored, signedInAccountID: "u1"))
        #expect(!shouldKeepWidgetSnapshot(stored, signedInAccountID: "u2"))
        #expect(!shouldKeepWidgetSnapshot(stored, signedInAccountID: nil))
        #expect(!shouldKeepWidgetSnapshot(nil, signedInAccountID: "u1"))
    }

    @Test func deepLinksPickATab() {
        #expect(appTab(forDeepLink: URL(string: "aura://quests")!) == .quests)
        #expect(appTab(forDeepLink: URL(string: "aura://crew")!) == .crew)
        #expect(appTab(forDeepLink: URL(string: "aura://nowhere")!) == nil)
        #expect(appTab(forDeepLink: URL(string: "https://quests")!) == nil)
    }
}
