import Testing
import Foundation
@testable import Aura

@MainActor
struct ProximityTests {
    let wall = Coordinate(latitude: 6.9130, longitude: 79.8610)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let precise = LocationAccess.allowed(isPrecise: true)

    func fix(metersNorth: Double, accuracy: Double = 5, secondsOld: TimeInterval = 1) -> LocationFix {
        LocationFix(
            coordinate: Coordinate(latitude: wall.latitude + metersNorth / metersPerDegreeLatitude, longitude: wall.longitude),
            horizontalAccuracyMeters: accuracy,
            timestamp: now.addingTimeInterval(-secondsOld)
        )
    }

    func proximity(_ fix: LocationFix?, access: LocationAccess? = nil) -> WallProximity {
        wallProximity(wallCoordinate: wall, access: access ?? precise, fix: fix, policy: wallReadingPolicy, now: now)
    }

    @Test func unlocksInsideRadius() {
        #expect(proximity(fix(metersNorth: 10)) == .unlocked)
        #expect(proximity(fix(metersNorth: 49)) == .unlocked)
    }

    @Test func staysLockedJustOutsideRadius() {
        guard case .tooFar(let distance) = proximity(fix(metersNorth: 51)) else {
            Issue.record("expected tooFar")
            return
        }
        #expect(abs(distance - 51) < 1)
    }

    @Test func locationOffOrApproximateLocks() {
        #expect(proximity(fix(metersNorth: 1), access: .denied) == .locationOff)
        #expect(proximity(fix(metersNorth: 1), access: .restricted) == .locationOff)
        #expect(proximity(fix(metersNorth: 1), access: .notAsked) == .locationOff)
        #expect(proximity(fix(metersNorth: 1), access: .allowed(isPrecise: false)) == .approximateLocation)
    }

    @Test func badOrOldFixKeepsSearching() {
        #expect(proximity(nil) == .findingLocation)
        #expect(proximity(fix(metersNorth: 1, accuracy: 26)) == .findingLocation)
        #expect(proximity(fix(metersNorth: 1, accuracy: -1)) == .findingLocation)
        #expect(proximity(fix(metersNorth: 1, secondsOld: 121)) == .findingLocation)
        #expect(proximity(fix(metersNorth: 1, accuracy: 25, secondsOld: 120)) == .unlocked)
    }

    @Test func lockedMessagesMentionTheRadius() {
        #expect(lockedWallMessage(for: .unlocked, policy: wallReadingPolicy) == nil)
        #expect(lockedWallMessage(for: .tooFar(distanceMeters: 320), policy: wallReadingPolicy) == "Walk within 50 m to read this wall. You're 320 m away.")
    }

    @Test(arguments: [(0, "No messages yet"), (1, "1 message"), (3, "3 messages")])
    func countLabels(count: Int, expected: String) {
        #expect(messageCountText(count) == expected)
    }
}
