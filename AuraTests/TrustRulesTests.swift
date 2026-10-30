import Testing
import Foundation
@testable import Aura

@MainActor
struct TrustRulesTests {
    let today = 20_400

    func message(author: String = "a", type: MessageContentType = .text) -> WallMessage {
        WallMessage(id: "m", wallID: "w", authorID: author, authorName: "A", text: "hi", color: .magenta, sparkCount: 0, createdAt: Date(timeIntervalSince1970: 0), contentType: type)
    }

    // Points
    @Test func aDiscoveryPaysTenPointsAndCountsOnce() {
        let after = statsAfterDiscovery(UserStats(), wallID: "w1", today: today)
        #expect(after.balance == discoveryRewardPoints)
        #expect(after.lifetimeXP == discoveryRewardPoints)
        #expect(after.discoveryCount == 1)
        #expect(after.lastDiscoveryWallID == "w1")
    }

    @Test func discoveriesOnTheSameDayBuildTheDailyCount() {
        let first = statsAfterDiscovery(UserStats(), wallID: "a", today: today)
        let second = statsAfterDiscovery(first, wallID: "b", today: today)
        #expect(second.dailyDiscoveries == 2)
        #expect(second.streakDays == 1)
    }

    @Test func aNewDayRestartsTheDailyCount() {
        let first = statsAfterDiscovery(UserStats(), wallID: "a", today: today)
        let next = statsAfterDiscovery(first, wallID: "b", today: today + 1)
        #expect(next.dailyDiscoveries == 1)
        #expect(next.streakDays == 2)
    }

    @Test func aNewWeekRestartsTheWeeklyCount() {
        let monday = weekStartDay(forDay: today)
        let thisWeek = statsAfterDiscovery(UserStats(), wallID: "a", today: monday)
        let nextWeek = statsAfterDiscovery(thisWeek, wallID: "b", today: monday + 7)
        #expect(nextWeek.weekDiscoveries == 1)
        #expect(nextWeek.weekStartDay == monday + 7)
    }

    @Test func theWeekAlwaysStartsOnAMondayWithinSevenDays() {
        for day in today..<(today + 21) {
            let start = weekStartDay(forDay: day)
            #expect(start <= day && day - start < 7)
            #expect(weekStartDay(forDay: start) == start)
        }
    }

    // Streaks
    @Test func missingOneDayWithAFreezeKeepsTheStreak() {
        let result = streakQualifyingOutcome(streakDays: 4, lastQualifiedDay: today - 2, today: today, freezes: 1)
        #expect(result.streak == 5 && result.usedFreeze)
    }

    @Test func missingOneDayWithoutAFreezeResetsTheStreak() {
        let result = streakQualifyingOutcome(streakDays: 4, lastQualifiedDay: today - 2, today: today, freezes: 0)
        #expect(result.streak == 1 && !result.usedFreeze)
    }

    @Test func missingTwoDaysResetsEvenWithAFreeze() {
        let result = streakQualifyingOutcome(streakDays: 4, lastQualifiedDay: today - 3, today: today, freezes: 2)
        #expect(result.streak == 1 && !result.usedFreeze)
    }

    @Test func aLapsedStreakShowsAsZero() {
        let stats = UserStats(streakDays: 6, lastQualifiedDay: today - 5)
        #expect(displayedStreak(stats, today: today) == 0)
    }

    // Spending
    @Test func publishingTakesExactlyTheCost() {
        let after = statsAfterWallPublish(UserStats(balance: 1_000), wallID: "w")
        #expect(after.balance == 1_000 - publicWallCost)
        #expect(after.wallsPublished == 1)
        #expect(after.lastPublishedWallID == "w")
    }

    @Test func nobodyCanAffordNegativeAmounts() {
        #expect(!canAfford(balance: -5, cost: 0))
        #expect(!canAfford(balance: 100, cost: -1))
        #expect(canAfford(balance: 50, cost: 50))
        #expect(!canAfford(balance: 49, cost: 50))
    }

    @Test func newUsersStartWithTheWelcomeBonusOnly() {
        let stats = newUserStats()
        #expect(stats.balance == welcomeBonusPoints)
        #expect(stats.lifetimeXP == 0)
        #expect(level(forXP: stats.lifetimeXP) == 1)
    }

    @Test func levelsChangeExactlyAtTheThresholds() {
        #expect(level(forXP: 99) == 1)
        #expect(level(forXP: 100) == 2)
        #expect(levelProgress(forXP: 4_000) == nil)
    }

    // Quests
    @Test func everyDayHasOneReadingAndOneWritingQuest() {
        for day in today..<(today + 12) {
            let quests = questsForDay(day)
            #expect(quests.count == 2)
            #expect(quests[0].kind == .discoveries)
            #expect(quests[1].kind != .discoveries)
            #expect(questsForDay(day) == quests)
        }
    }

    @Test func questProgressStopsAtTheTarget() {
        let quest = readingQuestPool[0]
        let stats = UserStats(dailyDay: today, dailyDiscoveries: 99)
        #expect(questProgress(quest, stats: stats, counters: DailyCounters(), today: today) == quest.target)
    }

    @Test func yesterdaysProgressDoesNotCountToday() {
        let stats = UserStats(dailyDay: today - 1, dailyDiscoveries: 5)
        let counters = DailyCounters(day: today - 1, posts: 3, drawings: 2)
        for quest in questCatalog {
            #expect(questProgress(quest, stats: stats, counters: counters, today: today) == 0)
        }
    }

    @Test func aClaimedQuestStaysClaimedWhateverTheProgress() {
        let quest = writingQuestPool[0]
        let state = questState(quest, stats: UserStats(), counters: DailyCounters(), claimedQuestIDs: [quest.id], today: today)
        #expect(state == .claimed)
    }

    @Test func finishingAQuestMakesItReadyOnce() {
        let quest = writingQuestPool[0]
        let counters = DailyCounters(day: today, posts: 1)
        #expect(questState(quest, stats: UserStats(), counters: counters, claimedQuestIDs: [], today: today) == .readyToClaim)
    }

    @Test func onlyTodaysClaimIDsCount() {
        let ids: Set<String> = [questClaimID(day: today, questID: "postOne"), questClaimID(day: today - 1, questID: "readFive")]
        #expect(claimedQuestIDs(fromClaimIDs: ids, today: today) == ["postOne"])
    }

    @Test func claimingAQuestAddsItsRewardToBalanceAndXP() {
        let quest = readingQuestPool[1]
        let after = statsAfterQuestClaim(UserStats(balance: 10), quest: quest, today: today)
        #expect(after.balance == 10 + quest.reward)
        #expect(after.lifetimeXP == quest.reward)
        #expect(after.lastClaimID == "\(today)_readFive")
    }

    // Shop
    @Test func theBrushCanOnlyBeBoughtOnce() {
        let brush = shopCatalog[0]
        let stats = UserStats(balance: 1_000)
        #expect(shopAvailability(for: brush, stats: stats, ownedItemIDs: []) == .available)
        #expect(shopAvailability(for: brush, stats: stats, ownedItemIDs: [brush.id.rawValue]) == .owned)
    }

    @Test func tooFewPointsSaysHowManyAreMissing() {
        let brush = shopCatalog[0]
        #expect(shopAvailability(for: brush, stats: UserStats(balance: 100), ownedItemIDs: []) == .notEnoughPoints(missing: brush.price - 100))
    }

    @Test func freezesStopAtTheHoldingLimit() {
        let freeze = shopCatalog[1]
        let stats = UserStats(balance: 1_000, streakFreezes: maximumStreakFreezes)
        #expect(shopAvailability(for: freeze, stats: stats, ownedItemIDs: []) == .limitReached)
    }

    @Test func buyingAFreezeCostsItsPriceAndAddsOne() {
        let freeze = shopCatalog[1]
        let after = statsAfterPurchase(UserStats(balance: 500), item: freeze, purchaseID: "p1")
        #expect(after.balance == 500 - freeze.price)
        #expect(after.streakFreezes == 1)
        #expect(after.lastPurchaseID == "p1")
    }

    @Test func buyingTheBrushDoesNotGrantAFreeze() {
        let brush = shopCatalog[0]
        let after = statsAfterPurchase(UserStats(balance: 500), item: brush, purchaseID: "p2")
        #expect(after.streakFreezes == 0)
        #expect(after.balance == 500 - brush.price)
    }

    // Messages
    @Test func aRetryReusesTheIDSoItCannotPostTwice() {
        let pending = PendingPost(id: "keep", text: "hello", color: .mint)
        #expect(messageIDForPost(text: "hello", color: .mint, previous: pending, makeID: { "new" }) == "keep")
        #expect(messageIDForPost(text: "hello!", color: .mint, previous: pending, makeID: { "new" }) == "new")
        #expect(messageIDForPost(text: "hello", color: .ink, previous: pending, makeID: { "new" }) == "new")
    }

    @Test func nobodySparksTheirOwnMessage() {
        #expect(!canSpark(message(author: "me"), userID: "me"))
        #expect(canSpark(message(author: "other"), userID: "me"))
    }

    @Test func onlyAuthorsEditOrDeleteAndOnlyTextCanBeEdited() {
        #expect(canEdit(message(author: "me"), userID: "me"))
        #expect(!canEdit(message(author: "me", type: .drawing), userID: "me"))
        #expect(!canEdit(message(author: "other"), userID: "me"))
        #expect(canDelete(message(author: "me"), userID: "me"))
        #expect(!canDelete(message(author: "other"), userID: "me"))
        #expect(canMove(message(author: "me", type: .drawing), userID: "me"))
        #expect(!canMove(message(author: "other"), userID: "me"))
    }

    @Test func sparkCountsNeverGoBelowZero() {
        #expect(sparkCountAfterToggle(0, isAddingSpark: false) == 0)
        #expect(sparkCountAfterToggle(0, isAddingSpark: true) == 1)
    }

    @Test func placementsStayInsideTheWallAndDoNotChange() {
        for id in ["a", "b", "message-123", ""] {
            let first = messagePlacement(forMessageID: id)
            #expect(first.x >= 0.1 - 0.0001 && first.x <= 0.9 + 0.0001 && first.y >= 0.1 - 0.0001 && first.y <= 0.9 + 0.0001)
            #expect(messagePlacement(forMessageID: id) == first)
        }
    }

    @Test func draggedMessagesCannotLeaveTheWall() {
        #expect(clampedPlacement(-1) == 0.05)
        #expect(clampedPlacement(2) == 0.95)
    }
}
