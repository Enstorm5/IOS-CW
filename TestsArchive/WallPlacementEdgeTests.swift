import Testing
import Foundation
@testable import Aura

@MainActor
struct WallPlacementEdgeTests {
    let origin = Coordinate(latitude: 6.9110, longitude: 79.8640)
    let now = Date(timeIntervalSince1970: 100_000)

    func fix(accuracy: Double = 5, age: TimeInterval = 1, latitudeOffset: Double = 0) -> LocationFix {
        LocationFix(
            coordinate: Coordinate(latitude: origin.latitude + latitudeOffset, longitude: origin.longitude),
            horizontalAccuracyMeters: accuracy,
            timestamp: now.addingTimeInterval(-age)
        )
    }

    // Wall size
    @Test func badPinchValuesKeepTheStartingSize() {
        let start = WallSize(width: 1.2, height: 0.8)
        #expect(resizedWallSize(start: start, pinchScale: .nan) == start)
        #expect(resizedWallSize(start: start, pinchScale: 0) == start)
        #expect(resizedWallSize(start: start, pinchScale: -2) == start)
        #expect(resizedWallSize(start: start, pinchScale: .infinity) == start)
    }

    @Test func steppingDownStopsAtTheMinimum() {
        let small = steppedWallSize(WallSize(width: 0.6, height: 0.6), widthSteps: -5, heightSteps: -5)
        #expect(small == WallSize(width: minimumWallSideMeters, height: minimumWallSideMeters))
    }

    @Test func steppingUpStopsAtTheMaximum() {
        let big = steppedWallSize(WallSize(width: 2.9, height: 2.9), widthSteps: 5, heightSteps: 5)
        #expect(big == WallSize(width: maximumWallSideMeters, height: maximumWallSideMeters))
    }

    @Test func theFrameFitStaysFiniteAtTheSizeLimits() {
        for side in [minimumWallSideMeters, maximumWallSideMeters] {
            let fit = wallFrameFit(for: WallSize(width: side, height: side))
            #expect(fit.scale.x > 0 && fit.scale.y > 0 && fit.scale.z > 0)
            #expect(fit.panelHeight > 0)
            #expect(fit.panelHeight.isFinite)
        }
    }

    // Wall name
    @Test func aNameOfOnlySpacesIsRejected() {
        #expect(wallTitleValidationError("    ") == "Give your wall a name.")
    }

    @Test func spacesAroundTheNameDoNotCount() {
        #expect(wallTitleValidationError("  ab  ") == nil)
        #expect(wallTitleValidationError(" a ") != nil)
        #expect(wallTitleValidationError(String(repeating: "a", count: 40)) == nil)
        #expect(wallTitleValidationError(String(repeating: "a", count: 41)) != nil)
    }

    // Message positions
    @Test func positionsOutsideTheWallAreClampedToItsEdges() {
        let size = WallSize(width: 2, height: 1)
        let low = messageCanvasPosition(normalizedX: -3, normalizedY: -3, size: size)
        let high = messageCanvasPosition(normalizedX: 9, normalizedY: 9, size: size)
        #expect(low.x == -1 && low.z == -0.5)
        #expect(high.x == 1 && high.z == 0.5)
    }

    @Test func theCentreOfTheWallIsTheAnchorOrigin() {
        let centre = messageCanvasPosition(normalizedX: 0.5, normalizedY: 0.5, size: defaultWallSize)
        #expect(centre.x == 0 && centre.z == 0)
    }

    @Test func textIsOnlyFlippedWhenTheWallAnchorPointsUp() {
        #expect(canvasNeedsFlip(anchorZAxisWorldY: 0.9))
        #expect(!canvasNeedsFlip(anchorZAxisWorldY: 0))
        #expect(!canvasNeedsFlip(anchorZAxisWorldY: -0.9))
    }

    // Publish location
    @Test func publishingIsBlockedWhenLocationIsOff() {
        #expect(publishLocationError(access: .notAsked, fix: fix(), now: now) != nil)
        #expect(publishLocationError(access: .denied, fix: fix(), now: now) != nil)
        #expect(publishLocationError(access: .restricted, fix: fix(), now: now) != nil)
    }

    @Test func publishingNeedsPreciseLocation() {
        #expect(publishLocationError(access: .allowed(isPrecise: false), fix: fix(), now: now) == "Turn on Precise Location to publish a wall.")
    }

    @Test func publishingRejectsStaleInvalidAndBlurryFixes() {
        let access = LocationAccess.allowed(isPrecise: true)
        #expect(publishLocationError(access: access, fix: nil, now: now) != nil)
        #expect(publishLocationError(access: access, fix: fix(age: 30), now: now) != nil)
        #expect(publishLocationError(access: access, fix: fix(accuracy: -1), now: now) != nil)
        #expect(publishLocationError(access: access, fix: fix(accuracy: 60), now: now) != nil)
        #expect(publishLocationError(access: access, fix: fix(), now: now) == nil)
    }

    // 50 m geofence
    @Test func standingAtTheWallUnlocksIt() {
        let result = wallProximity(wallCoordinate: origin, access: .allowed(isPrecise: true), fix: fix(), policy: wallReadingPolicy, now: now)
        #expect(result == .unlocked)
    }

    @Test func aboutOneHundredMetresAwayStaysLocked() {
        let result = wallProximity(wallCoordinate: origin, access: .allowed(isPrecise: true), fix: fix(latitudeOffset: 0.0009), policy: wallReadingPolicy, now: now)
        if case .tooFar(let meters) = result {
            #expect(meters > 90 && meters < 110)
        } else {
            Issue.record("Expected tooFar, got \(result)")
        }
    }

    @Test func aFixThirtyMetresAwayIsInsideTheGeofence() {
        let result = wallProximity(wallCoordinate: origin, access: .allowed(isPrecise: true), fix: fix(latitudeOffset: 0.0003), policy: wallReadingPolicy, now: now)
        #expect(result == .unlocked)
    }

    @Test func postingNeedsAFresherFixThanReading() {
        let old = fix(age: 60)
        let access = LocationAccess.allowed(isPrecise: true)
        #expect(wallProximity(wallCoordinate: origin, access: access, fix: old, policy: wallReadingPolicy, now: now) == .unlocked)
        #expect(wallProximity(wallCoordinate: origin, access: access, fix: old, policy: wallPostingPolicy, now: now) == .findingLocation)
    }

    @Test func aBlurryFixNeverUnlocksAWall() {
        let result = wallProximity(wallCoordinate: origin, access: .allowed(isPrecise: true), fix: fix(accuracy: 80), policy: wallReadingPolicy, now: now)
        #expect(result == .findingLocation)
    }

    @Test func approximateLocationNeverUnlocksAWall() {
        let result = wallProximity(wallCoordinate: origin, access: .allowed(isPrecise: false), fix: fix(), policy: wallReadingPolicy, now: now)
        #expect(result == .approximateLocation)
    }

    @Test func lockMessagesNameTheRadiusAndDistance() {
        let text = lockedWallMessage(for: .tooFar(distanceMeters: 120), policy: wallReadingPolicy)
        #expect(text?.contains("50 m") == true)
        #expect(lockedWallMessage(for: .unlocked, policy: wallReadingPolicy) == nil)
        #expect(postingBlockedMessage(for: .unlocked, policy: wallPostingPolicy) == nil)
        #expect(postingBlockedMessage(for: .findingLocation, policy: wallPostingPolicy) != nil)
    }

    // Wall ownership
    @Test func onlyTheOwnerOwnsAWall() {
        let wall = Wall(id: "w", title: "Mine", coordinate: origin, kind: .community, ownerID: "me")
        #expect(isWallOwner(wall, userID: "me"))
        #expect(!isWallOwner(wall, userID: "someone"))
        #expect(!isWallOwner(Wall(id: "w2", title: "Demo", coordinate: origin, kind: .community), userID: "me"))
    }

    @Test func renamingAnUnknownWallChangesNothing() {
        let walls = [Wall(id: "a", title: "A", coordinate: origin, kind: .community)]
        #expect(renamedWalls(walls, wallID: "zzz", title: "New") == walls)
    }

    @Test func aWallWithoutAMapSaysSo() {
        #expect(myWallDetail(Wall(id: "a", title: "A", coordinate: origin, kind: .community)) == "No AR map")
    }
}
