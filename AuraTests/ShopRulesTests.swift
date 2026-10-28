import Testing
import Foundation
@testable import Aura

@MainActor
struct ShopRulesTests {
    let today = 20_400
    let neon = shopCatalog.first { $0.id == .neonBrush }!
    let freeze = shopCatalog.first { $0.id == .streakFreeze }!

    @Test func catalogPricesMatchTheRules() {
        #expect(neon.price == 300)
        #expect(freeze.price == 150)
        #expect(shopItem(withID: "neonBrush") == neon)
        #expect(shopItem(withID: "wallSkin") == nil)
    }

    @Test func availabilityCoversEveryState() {
        let rich = UserStats(balance: 500)
        #expect(shopAvailability(for: neon, stats: rich, ownedItemIDs: []) == .available)
        #expect(shopAvailability(for: neon, stats: rich, ownedItemIDs: ["neonBrush"]) == .owned)
        #expect(shopAvailability(for: neon, stats: UserStats(balance: 100), ownedItemIDs: []) == .notEnoughPoints(missing: 200))
        #expect(shopAvailability(for: freeze, stats: UserStats(balance: 150), ownedItemIDs: []) == .available)
        #expect(shopAvailability(for: freeze, stats: UserStats(balance: 149), ownedItemIDs: []) == .notEnoughPoints(missing: 1))
        #expect(shopAvailability(for: freeze, stats: UserStats(balance: 999, streakFreezes: 2), ownedItemIDs: []) == .limitReached)
        #expect(shopAvailability(for: freeze, stats: UserStats(balance: 999, streakFreezes: 1), ownedItemIDs: []) == .available)
    }

    @Test func ownedItemIsCheckedBeforePoints() {
        #expect(shopAvailability(for: neon, stats: UserStats(balance: 0), ownedItemIDs: ["neonBrush"]) == .owned)
    }

    @Test func buttonAndMessageTexts() {
        #expect(shopButtonTitle(for: neon, availability: .available) == "Buy for 300 pts")
        #expect(shopButtonTitle(for: neon, availability: .owned) == "Owned")
        #expect(shopButtonTitle(for: neon, availability: .notEnoughPoints(missing: 120)) == "Need 120 pts more")
        #expect(shopButtonTitle(for: freeze, availability: .limitReached) == "Holding the most")
        #expect(shopStatusText(for: freeze, stats: UserStats(streakFreezes: 1)) == "You have 1 of 2.")
        #expect(shopStatusText(for: neon, stats: UserStats()) == nil)
        #expect(shopRefusalMessage(for: .owned, item: neon) == "You already own the Neon brush.")
        #expect(shopRefusalMessage(for: .limitReached, item: freeze) == "You already hold 2 streak freezes.")
    }

    @Test func purchaseDebitsAndGrants() {
        let before = UserStats(balance: 500, lifetimeXP: 90, discoveryCount: 4)
        let afterNeon = statsAfterPurchase(before, item: neon, purchaseID: "p1")
        #expect(afterNeon.balance == 200)
        #expect(afterNeon.lifetimeXP == 90 && afterNeon.discoveryCount == 4)
        #expect(afterNeon.lastPurchaseID == "p1")
        #expect(afterNeon.streakFreezes == 0)

        let afterFreeze = statsAfterPurchase(before, item: freeze, purchaseID: "p2")
        #expect(afterFreeze.balance == 350)
        #expect(afterFreeze.streakFreezes == 1)
    }

    @Test func freezeKeepsTheStreakAfterOneMissedDay() {
        let stats = UserStats(streakDays: 5, lastQualifiedDay: today - 2, streakFreezes: 1)
        let outcome = streakQualifyingOutcome(streakDays: 5, lastQualifiedDay: today - 2, today: today, freezes: 1)
        #expect(outcome.streak == 6 && outcome.usedFreeze)

        let after = statsAfterDiscovery(stats, wallID: "w", today: today)
        #expect(after.streakDays == 6)
        #expect(after.streakFreezes == 0)
        #expect(after.longestStreak == 6)
    }

    func outcomeText(streak: Int, last: Int, freezes: Int) -> String {
        let outcome = streakQualifyingOutcome(streakDays: streak, lastQualifiedDay: last, today: today, freezes: freezes)
        return "\(outcome.streak) \(outcome.usedFreeze)"
    }

    @Test func freezeIsNotUsedWhenItCannotHelp() {
        #expect(outcomeText(streak: 5, last: today - 3, freezes: 2) == "1 false")
        #expect(outcomeText(streak: 5, last: today - 1, freezes: 2) == "6 false")
        #expect(outcomeText(streak: 5, last: today, freezes: 2) == "5 false")
        #expect(outcomeText(streak: 5, last: today - 2, freezes: 0) == "1 false")
        #expect(outcomeText(streak: 0, last: today - 2, freezes: 1) == "1 false")

        let kept = statsAfterDiscovery(UserStats(streakDays: 5, lastQualifiedDay: today - 1, streakFreezes: 2), wallID: "w", today: today)
        #expect(kept.streakFreezes == 2)
    }

    @Test func streakShowsAsProtectedOnlyForOneMissedDay() {
        let stats = UserStats(streakDays: 5, lastQualifiedDay: today - 2, streakFreezes: 1)
        #expect(displayedStreak(stats, today: today) == 5)
        #expect(isStreakProtectedByFreeze(stats, today: today))
        #expect(displayedStreak(stats, today: today + 1) == 0)
        #expect(displayedStreak(UserStats(streakDays: 5, lastQualifiedDay: today - 2), today: today) == 0)
    }

    @Test func homeStreakTextMentionsFreezes() {
        #expect(streakSummary(UserStats(streakDays: 3, lastQualifiedDay: today, streakFreezes: 1), today: today) == "3 day streak · 1 freeze ready")
        #expect(streakSummary(UserStats(streakDays: 3, lastQualifiedDay: today, streakFreezes: 2), today: today) == "3 day streak · 2 freezes ready")
    }

    @Test func widgetKeepsAFrozenStreak() {
        let snapshot = WidgetSnapshot(accountID: "u", balance: 0, streakDays: 4, lastQualifiedDay: today - 2, questsDay: 0, questsDone: 0, questsTotal: 2, updatedAt: Date(), streakFreezes: 1)
        #expect(widgetStreak(snapshot, today: today) == 4)
        var noFreeze = snapshot
        noFreeze.streakFreezes = nil
        #expect(widgetStreak(noFreeze, today: today) == 0)
    }

    @Test func oldStatsReadAsNoFreezes() {
        let old = userStats(fields: ["balance": 10])
        #expect(old.streakFreezes == 0 && old.lastPurchaseID == "")
    }

    @Test func neonStrokesRoundTripAndMarkerStaysCompact() {
        let neonStroke = DrawingStroke(color: .mint, width: .thick, brush: .neon, points: [DrawingPoint(x: 0.1, y: 0.2), DrawingPoint(x: 0.3, y: 0.4)])
        let markerStroke = DrawingStroke(color: .ink, width: .thin, points: [DrawingPoint(x: 0.5, y: 0.5)])
        let drawing = MessageDrawing(strokes: [neonStroke, markerStroke])
        let payload = encodeDrawing(drawing)
        #expect(payload != nil)
        #expect(decodeDrawing(payload ?? "") == drawing)
        #expect(payload?.components(separatedBy: "brush").count == 2)
    }

    @Test func oldDrawingsWithoutABrushStillOpenAsMarker() {
        let old = #"{"strokes":[{"color":"magenta","points":[{"x":0.1,"y":0.1},{"x":0.5,"y":0.5}],"width":"medium"}]}"#
        let decoded = decodeDrawing(old)
        #expect(decoded?.strokes.first?.brush == .marker)
    }

    @Test func neonGlowHasThreeFadingLayers() {
        #expect(neonGlowLayers.count == 3)
        #expect(neonGlowLayers.map(\.widthScale) == neonGlowLayers.map(\.widthScale).sorted(by: >))
        #expect(neonCoreWidthScale < 1)
    }
}
