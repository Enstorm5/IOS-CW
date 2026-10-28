import Testing
import Foundation
@testable import Aura

@MainActor
struct QuestsTests {
    let today = 20_400

    func questNamed(_ id: String) -> Quest { quest(withID: id)! }

    @Test func catalogHasFiveQuestsWithTheRulesNumbers() {
        #expect(questCatalog.map(\.id) == ["readThree", "readFive", "readEight", "postOne", "drawOne"])
        #expect(questCatalog.map(\.reward) == [25, 40, 70, 20, 30])
        #expect(questCatalog.map(\.target) == [3, 5, 8, 1, 1])
        #expect(quest(withID: "nope") == nil)
    }

    @Test func eachDayHasOneReadingAndOneWritingQuest() {
        for day in today..<(today + 12) {
            let quests = questsForDay(day)
            #expect(quests.count == 2)
            #expect(readingQuestPool.contains(quests[0]))
            #expect(writingQuestPool.contains(quests[1]))
        }
    }

    @Test func rotationFollowsTheDayNumberLikeTheRules() {
        #expect(questsForDay(20_400).map(\.id) == ["readThree", "postOne"])
        #expect(questsForDay(20_401).map(\.id) == ["readFive", "drawOne"])
        #expect(questsForDay(20_402).map(\.id) == ["readEight", "postOne"])
        #expect(questsForDay(20_403).map(\.id) == ["readThree", "drawOne"])
    }

    @Test func everyQuestAppearsWithinASixDayCycle() {
        let ids = Set((today..<(today + 6)).flatMap { questsForDay($0).map(\.id) })
        #expect(ids == Set(questCatalog.map(\.id)))
        #expect(questsForDay(today).map(\.id) == questsForDay(today + 6).map(\.id))
    }

    @Test func claimIDsAndClaimedSetsUseTheDayPrefix() {
        #expect(questClaimID(day: today, questID: "readFive") == "20400_readFive")
        let ids: Set<String> = ["20400_readThree", "20399_readFive", "20400_postOne", "204000_drawOne"]
        #expect(claimedQuestIDs(fromClaimIDs: ids, today: today) == ["readThree", "postOne"])
    }

    @Test func readingQuestsUseTodaysDiscoveries() {
        let stats = UserStats(dailyDay: today, dailyDiscoveries: 4)
        #expect(questProgress(questNamed("readFive"), stats: stats, counters: DailyCounters(), today: today) == 4)
        #expect(questProgress(questNamed("readThree"), stats: stats, counters: DailyCounters(), today: today) == 3)
        #expect(questProgress(questNamed("readFive"), stats: stats, counters: DailyCounters(), today: today + 1) == 0)
    }

    @Test func writingQuestsUseTodaysCounters() {
        let counters = DailyCounters(day: today, posts: 3, drawings: 0)
        #expect(questProgress(questNamed("postOne"), stats: UserStats(), counters: counters, today: today) == 1)
        #expect(questProgress(questNamed("drawOne"), stats: UserStats(), counters: counters, today: today) == 0)
        #expect(questProgress(questNamed("postOne"), stats: UserStats(), counters: counters, today: today + 1) == 0)
        #expect(countersForToday([counters], today: today + 1) == DailyCounters(day: today + 1))
        #expect(countersForToday([counters], today: today) == counters)
    }

    @Test func stateMovesFromProgressToReadyToClaimed() {
        let readFive = questNamed("readFive")
        let stats = UserStats(dailyDay: today, dailyDiscoveries: 2)
        #expect(questState(readFive, stats: stats, counters: DailyCounters(), claimedQuestIDs: [], today: today) == .inProgress(2))

        let ready = UserStats(dailyDay: today, dailyDiscoveries: 6)
        #expect(questState(readFive, stats: ready, counters: DailyCounters(), claimedQuestIDs: [], today: today) == .readyToClaim)
        #expect(questState(readFive, stats: ready, counters: DailyCounters(), claimedQuestIDs: ["readFive"], today: today) == .claimed)
        #expect(questState(readFive, stats: ready, counters: DailyCounters(), claimedQuestIDs: ["readThree"], today: today) == .readyToClaim)
    }

    @Test func claimPaysTheQuestRewardAndLeavesOtherCountersAlone() {
        let before = UserStats(balance: 10, lifetimeXP: 10, discoveryCount: 6, dailyDay: today, dailyDiscoveries: 6, weekStartDay: 20_395, weekDiscoveries: 4)
        let after = statsAfterQuestClaim(before, quest: questNamed("readEight"), today: today)
        #expect(after.balance == 80 && after.lifetimeXP == 80)
        #expect(after.questsClaimed == 1)
        #expect(after.lastClaimID == "20400_readEight")
        #expect(after.discoveryCount == 6 && after.dailyDiscoveries == 6 && after.weekDiscoveries == 4)
    }

    @Test func textsDescribeEachState() {
        let readThree = questNamed("readThree")
        #expect(questStatusText(readThree, state: .inProgress(1)) == "1 of 3 · +25 pts")
        #expect(questStatusText(readThree, state: .readyToClaim) == "Ready to claim · +25 pts")
        #expect(questStatusText(readThree, state: .claimed) == "Claimed today · +25 pts")
        #expect(questsSummary([]) == "0 of 0 quests done today.")
    }

    @Test func countersMapFromFirestoreAndGrowWithEachPost() {
        let loaded = dailyCounters(fields: ["day": today, "posts": 2, "drawings": 1])
        #expect(loaded == DailyCounters(day: today, posts: 2, drawings: 1))
        #expect(dailyCounters(fields: [:]) == DailyCounters())

        let text = counterFields(after: loaded, day: today, wallID: "w1", messageID: "m1", isDrawing: false)
        #expect(text["posts"] as? Int == 3 && text["drawings"] as? Int == 1)
        #expect(text["lastPostWallID"] as? String == "w1" && text["lastPostMessageID"] as? String == "m1")

        let drawing = counterFields(after: loaded, day: today, wallID: "w1", messageID: "m2", isDrawing: true)
        #expect(drawing["posts"] as? Int == 3 && drawing["drawings"] as? Int == 2)
    }

    @Test func aNewDayStartsTheCountersAtOne() {
        let yesterday = DailyCounters(day: today - 1, posts: 5, drawings: 2)
        let fields = counterFields(after: yesterday, day: today, wallID: "w", messageID: "m", isDrawing: true)
        #expect(fields["day"] as? Int == today)
        #expect(fields["posts"] as? Int == 1 && fields["drawings"] as? Int == 1)
    }
}
