import Testing
import Foundation
@testable import Aura

@MainActor
struct HomeRulesTests {
    let today = 20_400

    @Test func greetingUsesFirstNameAndTimeOfDay() {
        #expect(greetingText(name: "Mira Perera", hour: 8) == "Good morning, Mira")
        #expect(greetingText(name: "Mira", hour: 12) == "Good afternoon, Mira")
        #expect(greetingText(name: "Mira", hour: 17) == "Good evening, Mira")
        #expect(greetingText(name: "Mira", hour: 2) == "Good evening, Mira")
    }

    @Test func questSummaryCoversProgressReadyAndClaimed() {
        let started = UserStats(dailyDay: today, dailyDiscoveries: 2)
        #expect(dailyQuestSummary(started, today: today) == "Read 5 walls today: 2 of 5.")

        let yesterday = UserStats(dailyDay: today - 1, dailyDiscoveries: 4)
        #expect(dailyQuestSummary(yesterday, today: today) == "Read 5 walls today: 0 of 5.")

        let ready = UserStats(dailyDay: today, dailyDiscoveries: 5)
        #expect(dailyQuestSummary(ready, today: today) == "Quest complete. Claim +40 pts in Quests.")

        let claimed = UserStats(dailyDay: today, dailyDiscoveries: 5, lastClaimID: dailyQuestClaimID(today: today))
        #expect(dailyQuestSummary(claimed, today: today) == "Today's quest is done. +40 pts claimed.")
    }

    @Test func streakSummaryHandlesNoneOneAndMany() {
        #expect(streakSummary(UserStats(), today: today) == "No streak yet. Discover a wall to start one.")
        #expect(streakSummary(UserStats(streakDays: 1, lastQualifiedDay: today), today: today) == "1 day streak")
        #expect(streakSummary(UserStats(streakDays: 4, lastQualifiedDay: today - 1), today: today) == "4 day streak")
        #expect(streakSummary(UserStats(streakDays: 4, lastQualifiedDay: today - 2), today: today) == "No streak yet. Discover a wall to start one.")
    }

    @Test func nearbyAndOwnedSummaries() {
        #expect(nearbyWallsSummary(count: 0, isOffline: false) == "No walls within 1 km yet.")
        #expect(nearbyWallsSummary(count: 0, isOffline: true) == "No saved walls within 1 km.")
        #expect(nearbyWallsSummary(count: 1, isOffline: false) == "1 wall within 1 km")
        #expect(nearbyWallsSummary(count: 3, isOffline: true) == "3 walls within 1 km (saved)")
        #expect(ownedWallsSummary(count: 0) == "You haven't placed a wall yet.")
        #expect(ownedWallsSummary(count: 1) == "1 wall live")
        #expect(ownedWallsSummary(count: 2) == "2 walls live")
    }

    @Test func closestWallsSortsAndLimits() {
        let walls = [400.0, 50.0, 900.0, 120.0].enumerated().map { index, meters in
            NearbyWall(wall: Wall(id: "w\(index)", title: "W\(index)", coordinate: Coordinate(latitude: 0, longitude: 0), kind: .community), distanceMeters: meters)
        }
        #expect(closestWalls(walls, limit: 3).map(\.id) == ["w1", "w3", "w0"])
        #expect(closestWalls(walls, limit: 0).isEmpty)
        #expect(closestWalls([], limit: 3).isEmpty)
    }

    @Test func mapRefreshesOnlyWhenPublishCountGoesUp() {
        #expect(shouldRefreshMapAfterPublish(oldCount: 1, newCount: 2))
        #expect(!shouldRefreshMapAfterPublish(oldCount: nil, newCount: 2))
        #expect(!shouldRefreshMapAfterPublish(oldCount: 2, newCount: 2))
        #expect(!shouldRefreshMapAfterPublish(oldCount: 2, newCount: nil))
    }
}
