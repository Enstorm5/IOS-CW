import Testing
import Foundation
@testable import Aura

@MainActor
struct EconomyTests {
    let today = 20_400

    @Test func dayChangesAtMidnightColomboTime() {
        let colomboMidnightUTC = Date(timeIntervalSince1970: Double(today * secondsPerDay - colomboUTCOffsetSeconds))
        #expect(dayNumber(for: colomboMidnightUTC) == today)
        #expect(dayNumber(for: colomboMidnightUTC.addingTimeInterval(-1)) == today - 1)
        #expect(dayNumber(for: colomboMidnightUTC.addingTimeInterval(Double(secondsPerDay) - 1)) == today)
    }

    @Test func streakGrowsKeepsOrResets() {
        #expect(streakAfterQualifying(streakDays: 4, lastQualifiedDay: today, today: today) == 4)
        #expect(streakAfterQualifying(streakDays: 4, lastQualifiedDay: today - 1, today: today) == 5)
        #expect(streakAfterQualifying(streakDays: 4, lastQualifiedDay: today - 2, today: today) == 1)
        #expect(streakAfterQualifying(streakDays: 0, lastQualifiedDay: 0, today: today) == 1)
    }

    @Test func shownStreakDropsAfterAMissedDay() {
        let stats = UserStats(streakDays: 6, lastQualifiedDay: today - 1)
        #expect(displayedStreak(stats, today: today) == 6)
        #expect(displayedStreak(stats, today: today + 1) == 0)
    }

    @Test func discoveryAddsTenAndCountsTowardsTheQuest() {
        var stats = UserStats()
        stats = statsAfterDiscovery(stats, wallID: "w1", today: today)
        stats = statsAfterDiscovery(stats, wallID: "w2", today: today)
        #expect(stats.balance == 20)
        #expect(stats.lifetimeXP == 20)
        #expect(stats.discoveryCount == 2)
        #expect(stats.dailyDiscoveries == 2)
        #expect(stats.streakDays == 1)
        #expect(stats.lastDiscoveryWallID == "w2")

        let nextDay = statsAfterDiscovery(stats, wallID: "w3", today: today + 1)
        #expect(nextDay.dailyDiscoveries == 1)
        #expect(nextDay.streakDays == 2)
        #expect(nextDay.longestStreak == 2)
    }

    @Test func dailyQuestNeedsFiveAndPaysOncePerDay() {
        var stats = UserStats(dailyDay: today, dailyDiscoveries: 4)
        #expect(!canClaimDailyQuest(stats, today: today))
        #expect(dailyQuestProgress(stats, today: today) == 4)

        stats.dailyDiscoveries = 7
        #expect(dailyQuestProgress(stats, today: today) == 5)
        #expect(canClaimDailyQuest(stats, today: today))

        let claimed = statsAfterDailyQuestClaim(stats, today: today)
        #expect(claimed.balance == 40)
        #expect(claimed.questsClaimed == 1)
        #expect(!canClaimDailyQuest(claimed, today: today))
        #expect(!canClaimDailyQuest(claimed, today: today + 1))
        #expect(dailyQuestProgress(claimed, today: today + 1) == 0)
    }

    @Test func levelsFollowTheThresholds() {
        #expect(level(forXP: 0) == 1)
        #expect(level(forXP: 99) == 1)
        #expect(level(forXP: 100) == 2)
        let progress = levelProgress(forXP: 120)
        #expect(progress?.current == 20 && progress?.needed == 150)
        #expect(levelProgress(forXP: 10_000) == nil)
    }

    @Test func affordAndFormat() {
        #expect(canAfford(balance: publicWallCost, cost: publicWallCost))
        #expect(!canAfford(balance: publicWallCost - 1, cost: publicWallCost))
        #expect(!canAfford(balance: -5, cost: 0))
        #expect(formattedPoints(2_480) == "2,480 pts")
    }

    @Test func badgesComeFromStats() {
        let earned = badges(for: UserStats(discoveryCount: 12, longestStreak: 3, questsClaimed: 0))
        #expect(earned.filter(\.isEarned).map(\.id) == ["first-find", "wall-hunter", "on-a-roll"])
    }

    @Test func statsRoundTripThroughFirestoreFields() {
        let stats = UserStats(balance: 50, lifetimeXP: 90, discoveryCount: 5, streakDays: 2, longestStreak: 3,
                              lastQualifiedDay: today, dailyDay: today, dailyDiscoveries: 5, questsClaimed: 1,
                              lastDiscoveryWallID: "w5", lastClaimID: "20400_readFive", wallsPublished: 2, lastPublishedWallID: "w9")
        #expect(userStats(fields: firestoreFields(for: stats)) == stats)
        #expect(firestoreFields(for: UserStats()).count == 13)
    }
}
