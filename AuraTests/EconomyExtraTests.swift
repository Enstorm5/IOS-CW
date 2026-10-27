import Testing
import Foundation
@testable import Aura

@MainActor
struct EconomyExtraTests {
    let today = 20_400

    @Test func claimIDsIncludeTheDay() {
        #expect(dailyQuestClaimID(today: today) == "20400_readFive")
        #expect(dailyQuestClaimID(today: today) != dailyQuestClaimID(today: today + 1))
    }

    @Test func discoveryAfterAGapRestartsTheStreakButKeepsTheLongest() {
        var stats = UserStats()
        for offset in 0..<3 {
            stats = statsAfterDiscovery(stats, wallID: "w\(offset)", today: today + offset)
        }
        #expect(stats.streakDays == 3 && stats.longestStreak == 3)

        stats = statsAfterDiscovery(stats, wallID: "late", today: today + 6)
        #expect(stats.streakDays == 1)
        #expect(stats.longestStreak == 3)
    }

    @Test func questProgressResetsOnANewDay() {
        let stats = UserStats(dailyDay: today, dailyDiscoveries: 3)
        #expect(dailyQuestProgress(stats, today: today) == 3)
        #expect(dailyQuestProgress(stats, today: today + 1) == 0)
        #expect(!canClaimDailyQuest(UserStats(dailyDay: today + 1, dailyDiscoveries: 9), today: today))
    }

    @Test func claimNeverChangesDiscoveryCounters() {
        let before = UserStats(balance: 20, lifetimeXP: 20, discoveryCount: 5, streakDays: 2, longestStreak: 2, lastQualifiedDay: today, dailyDay: today, dailyDiscoveries: 5)
        let after = statsAfterDailyQuestClaim(before, today: today)
        #expect(after.discoveryCount == before.discoveryCount)
        #expect(after.streakDays == before.streakDays)
        #expect(after.dailyDiscoveries == before.dailyDiscoveries)
        #expect(after.lifetimeXP == 60)
    }

    @Test func spendingNeverLowersLifetimeXP() {
        var stats = UserStats()
        for index in 0..<10 { stats = statsAfterDiscovery(stats, wallID: "w\(index)", today: today) }
        #expect(stats.balance == 100 && stats.lifetimeXP == 100)
        #expect(level(forXP: stats.lifetimeXP) == 2)
    }

    @Test func missingFieldsDefaultToZero() {
        #expect(userStats(fields: [:]) == UserStats())
        #expect(userStats(fields: ["balance": "oops"]).balance == 0)
    }

    @Test func badgeProgressStopsAtTheTarget() {
        let all = badges(for: UserStats(discoveryCount: 999, longestStreak: 99, questsClaimed: 9, wallsPublished: 3))
        #expect(all.allSatisfy(\.isEarned))
        #expect(all.allSatisfy { $0.progress == $0.target })
        #expect(Set(all.map(\.id)).count == all.count)
    }

    @Test func levelCapsAtTheTopThreshold() {
        #expect(level(forXP: levelThresholds.last!) == levelThresholds.count)
        #expect(level(forXP: 1_000_000) == levelThresholds.count)
    }

    @Test func publishingSpendsPointsButKeepsXP() {
        let before = UserStats(balance: 120, lifetimeXP: 300, discoveryCount: 12)
        let after = statsAfterWallPublish(before, wallID: "w1")
        #expect(after.balance == 120 - publicWallCost)
        #expect(after.lifetimeXP == 300)
        #expect(after.wallsPublished == 1)
        #expect(after.lastPublishedWallID == "w1")
        #expect(after.discoveryCount == 12)
    }

    @Test func costMessageExplainsAShortfall() {
        #expect(publishCostMessage(balance: 120) == "Publishing costs 50 pts. You have 120 pts.")
        #expect(publishCostMessage(balance: 20).hasSuffix("Discover walls and claim quests to earn more."))
    }

    @Test func firstWallBadge() {
        #expect(badges(for: UserStats(wallsPublished: 1)).first { $0.id == "first-wall" }?.isEarned == true)
        #expect(badges(for: UserStats()).first { $0.id == "first-wall" }?.isEarned == false)
    }
}
