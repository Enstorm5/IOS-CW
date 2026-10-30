import Testing
import Foundation
import ARKit
@testable import Aura

@MainActor
struct CoreTests {
    let origin = Coordinate(latitude: 6.9110, longitude: 79.8640)
    let now = Date(timeIntervalSince1970: 100_000)
    let today = 20_400

    func fix(accuracy: Double = 5, age: TimeInterval = 1, latitudeOffset: Double = 0) -> LocationFix {
        LocationFix(
            coordinate: Coordinate(latitude: origin.latitude + latitudeOffset, longitude: origin.longitude),
            horizontalAccuracyMeters: accuracy,
            timestamp: now.addingTimeInterval(-age)
        )
    }

    func message(author: String, type: MessageContentType = .text) -> WallMessage {
        WallMessage(id: "m", wallID: "w", authorID: author, authorName: "A", text: "hi", color: .magenta, sparkCount: 0, createdAt: Date(timeIntervalSince1970: 0), contentType: type)
    }

    // AR: saving and restoring
    @Test func saveGate() {
        #expect(canSaveWorldMap(tracking: .normal, mapping: .mapped, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .limited, mapping: .mapped, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .normal, mapping: .extending, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .normal, mapping: .mapped, hasWallAnchor: false))
    }

    @Test func restoreGate() {
        #expect(isWallRestored(tracking: .normal, hasExpectedAnchor: true))
        #expect(!isWallRestored(tracking: .relocalizing, hasExpectedAnchor: true))
        #expect(!isWallRestored(tracking: .normal, hasExpectedAnchor: false))
    }

    @Test func restoreTimeout() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(!hasRelocalizationTimedOut(startedAt: start, now: start.addingTimeInterval(29.9), timeoutSeconds: relocalizationTimeoutSeconds))
        #expect(hasRelocalizationTimedOut(startedAt: start, now: start.addingTimeInterval(30), timeoutSeconds: relocalizationTimeoutSeconds))
    }

    @Test func trackingStatusMapping() {
        #expect(trackingStatus(from: .limited(.excessiveMotion)) == .movingTooFast)
        #expect(trackingStatus(from: .limited(.insufficientFeatures)) == .notEnoughDetail)
        #expect(trackingStatus(from: .limited(.relocalizing)) == .relocalizing)
        #expect(trackingStatus(from: .normal) == .normal)
        #expect(trackingGuidance(.normal) == nil)
        #expect(trackingGuidance(.movingTooFast) != nil)
    }

    @Test func badMapRejected() {
        #expect(throws: WorldMapArchiveError.corrupt) {
            try decodeWorldMap(Data("not a map".utf8), expectedAnchorName: "wall")
        }
        #expect(throws: WorldMapArchiveError.tooLarge) {
            try decodeWorldMap(Data(count: maximumWorldMapBytes + 1), expectedAnchorName: "wall")
        }
    }

    // AR: map transfer
    @Test func chunksJoinInOrder() {
        let chunks: [(index: Int, data: Data)] = [(2, Data([5, 6])), (0, Data([1, 2])), (1, Data([3, 4]))]
        #expect(joinedMapData(chunks: chunks, expectedCount: 3) == Data([1, 2, 3, 4, 5, 6]))
    }

    @Test func badChunksRejected() {
        #expect(joinedMapData(chunks: [(0, Data([1])), (2, Data([3]))], expectedCount: 3) == nil)
        #expect(joinedMapData(chunks: [(0, Data([1])), (0, Data([1])), (1, Data([2]))], expectedCount: 2) == nil)
    }

    @Test func maxMapChunkCount() {
        let chunks = splitIntoChunks(Data(count: maximumWorldMapBytes), chunkSize: mapChunkByteLimit)
        #expect(chunks.count <= 24)
        #expect(chunks.allSatisfy { $0.count <= mapChunkByteLimit })
    }

    @Test func checksumChanges() {
        var changed = Data([1, 2, 3, 4])
        let original = changed
        changed[2] = 9
        #expect(sha256Hex(original) != sha256Hex(changed))
        #expect(sha256Hex(Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    // AR: wall and messages
    @Test func wallSizeLimits() {
        #expect(clampedWallSide(0.1) == minimumWallSideMeters)
        #expect(clampedWallSide(9) == maximumWallSideMeters)
        let start = WallSize(width: 1.2, height: 0.8)
        #expect(resizedWallSize(start: start, pinchScale: .nan) == start)
        #expect(resizedWallSize(start: start, pinchScale: 0) == start)
    }

    @Test func frameFitLimits() {
        for side in [minimumWallSideMeters, maximumWallSideMeters] {
            let fit = wallFrameFit(for: WallSize(width: side, height: side))
            #expect(fit.scale.x > 0 && fit.scale.y > 0 && fit.scale.z > 0)
            #expect(fit.panelHeight > 0 && fit.panelHeight.isFinite)
        }
    }

    @Test func messagesStayOnWall() {
        let size = WallSize(width: 2, height: 1)
        let low = messageCanvasPosition(normalizedX: -3, normalizedY: -3, size: size)
        let high = messageCanvasPosition(normalizedX: 9, normalizedY: 9, size: size)
        #expect(low.x == -1 && low.z == -0.5)
        #expect(high.x == 1 && high.z == 0.5)
        #expect(clampedPlacement(-1) == 0.05 && clampedPlacement(2) == 0.95)
    }

    @Test func textFlip() {
        #expect(canvasNeedsFlip(anchorZAxisWorldY: 0.9))
        #expect(!canvasNeedsFlip(anchorZAxisWorldY: -0.9))
    }

    // Location and publishing
    @Test func geofence() {
        let access = LocationAccess.allowed(isPrecise: true)
        #expect(wallProximity(wallCoordinate: origin, access: access, fix: fix(), policy: wallReadingPolicy, now: now) == .unlocked)
        let far = wallProximity(wallCoordinate: origin, access: access, fix: fix(latitudeOffset: 0.0009), policy: wallReadingPolicy, now: now)
        if case .tooFar(let meters) = far {
            #expect(meters > 90 && meters < 110)
        } else {
            Issue.record("Expected tooFar, got \(far)")
        }
    }

    @Test func badLocationStaysLocked() {
        let precise = LocationAccess.allowed(isPrecise: true)
        #expect(wallProximity(wallCoordinate: origin, access: precise, fix: fix(accuracy: 80), policy: wallReadingPolicy, now: now) == .findingLocation)
        #expect(wallProximity(wallCoordinate: origin, access: .allowed(isPrecise: false), fix: fix(), policy: wallReadingPolicy, now: now) == .approximateLocation)
        #expect(wallProximity(wallCoordinate: origin, access: .denied, fix: fix(), policy: wallReadingPolicy, now: now) == .locationOff)
    }

    @Test func postingNeedsFreshFix() {
        let old = fix(age: 60)
        let access = LocationAccess.allowed(isPrecise: true)
        #expect(wallProximity(wallCoordinate: origin, access: access, fix: old, policy: wallReadingPolicy, now: now) == .unlocked)
        #expect(wallProximity(wallCoordinate: origin, access: access, fix: old, policy: wallPostingPolicy, now: now) == .findingLocation)
    }

    @Test func publishLocation() {
        let access = LocationAccess.allowed(isPrecise: true)
        #expect(publishLocationError(access: access, fix: fix(), now: now) == nil)
        #expect(publishLocationError(access: access, fix: fix(age: 30), now: now) != nil)
        #expect(publishLocationError(access: access, fix: fix(accuracy: 60), now: now) != nil)
        #expect(publishLocationError(access: .allowed(isPrecise: false), fix: fix(), now: now) != nil)
        #expect(publishLocationError(access: .denied, fix: nil, now: now) != nil)
    }

    @Test func wallTitleLength() {
        #expect(wallTitleValidationError("   ") != nil)
        #expect(wallTitleValidationError(" a ") != nil)
        #expect(wallTitleValidationError("ab") == nil)
        #expect(wallTitleValidationError(String(repeating: "a", count: 41)) != nil)
    }

    // Points and streaks
    @Test func discoveryPoints() {
        let first = statsAfterDiscovery(UserStats(), wallID: "a", today: today)
        let second = statsAfterDiscovery(first, wallID: "b", today: today)
        #expect(first.balance == discoveryRewardPoints && first.discoveryCount == 1)
        #expect(second.dailyDiscoveries == 2 && second.streakDays == 1)
    }

    @Test func newDayStreak() {
        let first = statsAfterDiscovery(UserStats(), wallID: "a", today: today)
        let next = statsAfterDiscovery(first, wallID: "b", today: today + 1)
        #expect(next.dailyDiscoveries == 1 && next.streakDays == 2)
    }

    @Test func streakFreeze() {
        let saved = streakQualifyingOutcome(streakDays: 4, lastQualifiedDay: today - 2, today: today, freezes: 1)
        let noFreeze = streakQualifyingOutcome(streakDays: 4, lastQualifiedDay: today - 2, today: today, freezes: 0)
        let twoDays = streakQualifyingOutcome(streakDays: 4, lastQualifiedDay: today - 3, today: today, freezes: 2)
        #expect(saved.streak == 5 && saved.usedFreeze)
        #expect(noFreeze.streak == 1 && !noFreeze.usedFreeze)
        #expect(twoDays.streak == 1 && !twoDays.usedFreeze)
    }

    @Test func lapsedStreak() {
        #expect(displayedStreak(UserStats(streakDays: 6, lastQualifiedDay: today - 5), today: today) == 0)
    }

    @Test func weekStartsMonday() {
        for day in today..<(today + 14) {
            let start = weekStartDay(forDay: day)
            #expect(start <= day && day - start < 7)
            #expect(weekStartDay(forDay: start) == start)
        }
    }

    @Test func publishCost() {
        let after = statsAfterWallPublish(UserStats(balance: 1_000), wallID: "w")
        #expect(after.balance == 1_000 - publicWallCost && after.wallsPublished == 1)
        #expect(canAfford(balance: 50, cost: 50))
        #expect(!canAfford(balance: 49, cost: 50))
        #expect(!canAfford(balance: -5, cost: 0))
    }

    @Test func welcomeBonus() {
        let stats = newUserStats()
        #expect(stats.balance == welcomeBonusPoints && stats.lifetimeXP == 0)
        #expect(level(forXP: 99) == 1 && level(forXP: 100) == 2)
    }

    // Quests and shop
    @Test func dailyQuests() {
        for day in today..<(today + 12) {
            let quests = questsForDay(day)
            #expect(quests.count == 2 && quests[0].kind == .discoveries && quests[1].kind != .discoveries)
            #expect(questsForDay(day) == quests)
        }
    }

    @Test func questProgressCap() {
        let quest = readingQuestPool[0]
        let today = UserStats(dailyDay: self.today, dailyDiscoveries: 99)
        let yesterday = UserStats(dailyDay: self.today - 1, dailyDiscoveries: 5)
        #expect(questProgress(quest, stats: today, counters: DailyCounters(), today: self.today) == quest.target)
        #expect(questProgress(quest, stats: yesterday, counters: DailyCounters(), today: self.today) == 0)
    }

    @Test func questClaimState() {
        let quest = writingQuestPool[0]
        let counters = DailyCounters(day: today, posts: 1)
        #expect(questState(quest, stats: UserStats(), counters: counters, claimedQuestIDs: [], today: today) == .readyToClaim)
        #expect(questState(quest, stats: UserStats(), counters: counters, claimedQuestIDs: [quest.id], today: today) == .claimed)
    }

    @Test func questReward() {
        let quest = readingQuestPool[1]
        let after = statsAfterQuestClaim(UserStats(balance: 10), quest: quest, today: today)
        #expect(after.balance == 10 + quest.reward && after.lifetimeXP == quest.reward)
        #expect(after.lastClaimID == "\(today)_readFive")
    }

    @Test func buyBrush() {
        let brush = shopCatalog[0]
        #expect(shopAvailability(for: brush, stats: UserStats(balance: 1_000), ownedItemIDs: []) == .available)
        #expect(shopAvailability(for: brush, stats: UserStats(balance: 1_000), ownedItemIDs: [brush.id.rawValue]) == .owned)
        #expect(shopAvailability(for: brush, stats: UserStats(balance: 100), ownedItemIDs: []) == .notEnoughPoints(missing: brush.price - 100))
    }

    @Test func buyFreeze() {
        let freeze = shopCatalog[1]
        let after = statsAfterPurchase(UserStats(balance: 500), item: freeze, purchaseID: "p1")
        #expect(after.balance == 500 - freeze.price && after.streakFreezes == 1 && after.lastPurchaseID == "p1")
        #expect(shopAvailability(for: freeze, stats: UserStats(balance: 1_000, streakFreezes: maximumStreakFreezes), ownedItemIDs: []) == .limitReached)
    }

    // Messages
    @Test func retryKeepsMessageID() {
        let pending = PendingPost(id: "keep", text: "hello", color: .mint)
        #expect(messageIDForPost(text: "hello", color: .mint, previous: pending, makeID: { "new" }) == "keep")
        #expect(messageIDForPost(text: "hello!", color: .mint, previous: pending, makeID: { "new" }) == "new")
    }

    @Test func messagePermissions() {
        #expect(canEdit(message(author: "me"), userID: "me"))
        #expect(!canEdit(message(author: "me", type: .drawing), userID: "me"))
        #expect(!canEdit(message(author: "other"), userID: "me"))
        #expect(canDelete(message(author: "me"), userID: "me") && !canDelete(message(author: "other"), userID: "me"))
        #expect(canMove(message(author: "me"), userID: "me") && !canMove(message(author: "other"), userID: "me"))
        #expect(!canSpark(message(author: "me"), userID: "me") && canSpark(message(author: "other"), userID: "me"))
    }

    @Test func messagePositions() {
        for id in ["a", "message-123", ""] {
            let first = messagePlacement(forMessageID: id)
            #expect(first.x >= 0.0999 && first.x <= 0.9001 && first.y >= 0.0999 && first.y <= 0.9001)
            #expect(messagePlacement(forMessageID: id) == first)
        }
    }

    @Test func sparkFloor() {
        #expect(sparkCountAfterToggle(0, isAddingSpark: false) == 0)
        #expect(sparkCountAfterToggle(0, isAddingSpark: true) == 1)
    }
}
