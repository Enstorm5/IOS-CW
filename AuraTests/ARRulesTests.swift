import Testing
import Foundation
import ARKit
@testable import Aura

@MainActor
struct ARRulesTests {

    @Test func saveNeedsNormalTrackingMappedAreaAndAnchor() {
        #expect(canSaveWorldMap(tracking: .normal, mapping: .mapped, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .normal, mapping: .extending, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .relocalizing, mapping: .mapped, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .normal, mapping: .mapped, hasWallAnchor: false))
    }

    @Test func restoreNeedsBothNormalTrackingAndTheAnchor() {
        #expect(isWallRestored(tracking: .normal, hasExpectedAnchor: true))
        #expect(!isWallRestored(tracking: .relocalizing, hasExpectedAnchor: true))
        #expect(!isWallRestored(tracking: .normal, hasExpectedAnchor: false))
    }

    @Test func mapsARKitStatuses() {
        #expect(mappingStatus(from: .mapped) == .mapped)
        #expect(mappingStatus(from: .extending) == .extending)
        #expect(trackingStatus(from: .normal) == .normal)
        #expect(trackingStatus(from: .limited(.relocalizing)) == .relocalizing)
        #expect(trackingStatus(from: .limited(.insufficientFeatures)) == .notEnoughDetail)
        #expect(trackingStatus(from: .notAvailable) == .notAvailable)
    }

    @Test func timeoutBoundary() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(!hasRelocalizationTimedOut(startedAt: start, now: start.addingTimeInterval(29.9), timeoutSeconds: 30))
        #expect(hasRelocalizationTimedOut(startedAt: start, now: start.addingTimeInterval(30), timeoutSeconds: 30))
    }

    @Test func guidanceOnlyWhenTrackingIsNotNormal() {
        #expect(trackingGuidance(.normal) == nil)
        #expect(trackingGuidance(.relocalizing) != nil)
        #expect(mappingGuidance(.mapped) == "Area mapped. You can save now.")
    }

    @Test func corruptAndOversizedArchivesAreRejected() {
        #expect(throws: WorldMapArchiveError.corrupt) {
            try decodeWorldMap(Data("not a map".utf8), expectedAnchorName: "wall")
        }
        #expect(throws: WorldMapArchiveError.tooLarge) {
            try decodeWorldMap(Data(count: maximumWorldMapBytes + 1), expectedAnchorName: "wall")
        }
    }

    @Test func errorMessagesAreReadable() {
        #expect(worldMapErrorMessage(WorldMapArchiveError.corrupt) == "The wall's map is damaged. Place the wall again.")
        #expect(formattedByteCount(3_565_158) == "3.4 MB")
    }
}
