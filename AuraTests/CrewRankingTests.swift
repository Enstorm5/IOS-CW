import Testing
import Foundation
@testable import Aura

@MainActor
struct CrewRankingTests {
    let monday = 20_395

    func member(_ id: String, joined: Double = 0, on: Bool = true, xp: Int = 0, week: Int? = nil, walls: Int = 0) -> CrewMember {
        CrewMember(id: id, displayName: id.capitalized, avatarPreset: .mint, joinedAt: Date(timeIntervalSince1970: joined),
                   showOnRankings: on, lifetimeXP: xp, weekStartDay: week ?? monday, weekDiscoveries: walls)
    }

    @Test func weekStartsOnMondayInColombo() {
        #expect(weekStartDay(forDay: 20_395) == 20_395)
        #expect(weekStartDay(forDay: 20_400) == 20_395)
        #expect(weekStartDay(forDay: 20_401) == 20_395)
        #expect(weekStartDay(forDay: 20_402) == 20_402)
    }

    @Test func discoveryCountsPerWeekAndResetsOnANewWeek() {
        var stats = UserStats()
        stats = statsAfterDiscovery(stats, wallID: "a", today: 20_395)
        stats = statsAfterDiscovery(stats, wallID: "b", today: 20_401)
        #expect(stats.weekStartDay == 20_395)
        #expect(stats.weekDiscoveries == 2)
        stats = statsAfterDiscovery(stats, wallID: "c", today: 20_402)
        #expect(stats.weekStartDay == 20_402)
        #expect(stats.weekDiscoveries == 1)
    }

    @Test func questClaimAndPublishLeaveTheWeekAlone() {
        let stats = UserStats(dailyDay: 20_400, dailyDiscoveries: 5, weekStartDay: 20_395, weekDiscoveries: 3)
        let claimed = statsAfterDailyQuestClaim(stats, today: 20_400)
        #expect(claimed.weekStartDay == 20_395 && claimed.weekDiscoveries == 3)
        let published = statsAfterWallPublish(UserStats(balance: 60, weekStartDay: 20_395, weekDiscoveries: 3), wallID: "w")
        #expect(published.weekStartDay == 20_395 && published.weekDiscoveries == 3)
    }

    @Test func oldStatsDocumentsWithoutWeekFieldsReadAsZero() {
        let old = userStats(fields: ["balance": 10, "lifetimeXP": 10])
        #expect(old.weekStartDay == 0 && old.weekDiscoveries == 0)
    }

    @Test func rankingsExcludeOptedOutAndOrderByXPWithStableTies() {
        let members = [
            member("low", xp: 10),
            member("hidden", on: false, xp: 999),
            member("top", xp: 300),
            member("tieLate", joined: 50, xp: 100),
            member("tieEarly", joined: 20, xp: 100),
        ]
        let ranked = rankedCrewMembers(members)
        #expect(ranked.map(\.member.id) == ["top", "tieEarly", "tieLate", "low"])
        #expect(ranked.map(\.rank) == [1, 2, 3, 4])
        #expect(rankedCrewMembers(members) == ranked)
    }

    @Test func sameJoinTimeFallsBackToID() {
        let ranked = rankedCrewMembers([member("b", xp: 5), member("a", xp: 5)])
        #expect(ranked.map(\.member.id) == ["a", "b"])
    }

    @Test func weeklyGoalCountsOnlyOptedInMembersThisWeek() {
        let members = [
            member("a", walls: 4),
            member("b", walls: 3),
            member("c", week: monday - 7, walls: 9),
            member("d", on: false, walls: 8),
        ]
        #expect(crewWeeklyGoal(members: members) == 15)
        #expect(crewWeeklyProgress(members: members, weekStart: monday) == 7)
        #expect(weeklyWalls(of: members[3], weekStart: monday) == 0)
        #expect(crewWeeklyGoal(members: [member("d", on: false)]) == 0)
    }

    @Test func goalAndRankingTexts() {
        #expect(weeklyGoalText(progress: 7, goal: 15) == "7 of 15 walls this week")
        #expect(weeklyGoalText(progress: 0, goal: 0) == "Turn on rankings to count towards the weekly goal.")
        #expect(rankingScoreText(member("a", xp: 120, walls: 1), weekStart: monday) == "120 XP · 1 wall this week")
        #expect(rankingScoreText(member("a", xp: 120, week: monday - 7, walls: 4), weekStart: monday) == "120 XP · 0 walls this week")
    }

    @Test func weekEndTextCountsDaysLeft() {
        func date(forDay day: Int) -> Date {
            Date(timeIntervalSince1970: Double(day * secondsPerDay - colomboUTCOffsetSeconds + 3_600))
        }
        #expect(weekEndsText(now: date(forDay: monday)) == "7 days left · Monday to Sunday")
        #expect(weekEndsText(now: date(forDay: monday + 5)) == "2 days left · Monday to Sunday")
        #expect(weekEndsText(now: date(forDay: monday + 6)) == "Ends tonight at midnight")
    }

    @Test func scoreCopiesStatsOnlyWhenOptedIn() {
        let stats = UserStats(lifetimeXP: 90, weekStartDay: monday, weekDiscoveries: 2)
        #expect(rankingScore(from: stats, showOnRankings: true) == RankingScore(showOnRankings: true, lifetimeXP: 90, weekStartDay: monday, weekDiscoveries: 2))
        #expect(rankingScore(from: stats, showOnRankings: false) == RankingScore(showOnRankings: false, lifetimeXP: 0, weekStartDay: 0, weekDiscoveries: 0))
    }

    @Test func syncIsNeededOnlyWhenOptedInAndOutOfDate() {
        let stats = UserStats(lifetimeXP: 90, weekStartDay: monday, weekDiscoveries: 2)
        #expect(needsScoreSync(member: member("a", xp: 80, walls: 2), stats: stats))
        #expect(needsScoreSync(member: member("a", xp: 90, walls: 1), stats: stats))
        #expect(!needsScoreSync(member: member("a", xp: 90, walls: 2), stats: stats))
        #expect(!needsScoreSync(member: member("a", on: false, xp: 0), stats: stats))
    }

    @Test func memberMappingReadsRankingFieldsWithDefaults() {
        let mapped = crewMember(id: "a", fields: ["displayName": "A", "showOnRankings": true, "lifetimeXP": 40, "weekStartDay": monday, "weekDiscoveries": 3])
        #expect(mapped?.showOnRankings == true && mapped?.lifetimeXP == 40 && mapped?.weekDiscoveries == 3)
        let plain = crewMember(id: "a", fields: ["displayName": "A"])
        #expect(plain?.showOnRankings == false && plain?.lifetimeXP == 0)
    }
}
