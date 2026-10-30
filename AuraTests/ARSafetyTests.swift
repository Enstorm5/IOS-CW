import Testing
import Foundation
import ARKit
@testable import Aura

@MainActor
struct ARSafetyTests {
    // Save gate
    @Test func savingIsBlockedWhileTrackingIsLimited() {
        #expect(!canSaveWorldMap(tracking: .limited, mapping: .mapped, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .movingTooFast, mapping: .mapped, hasWallAnchor: true))
    }

    @Test func savingIsBlockedUntilTheAreaIsMapped() {
        #expect(!canSaveWorldMap(tracking: .normal, mapping: .extending, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .normal, mapping: .limited, hasWallAnchor: true))
        #expect(!canSaveWorldMap(tracking: .normal, mapping: .notAvailable, hasWallAnchor: true))
    }

    @Test func savingIsBlockedWithoutAWallAnchor() {
        #expect(!canSaveWorldMap(tracking: .normal, mapping: .mapped, hasWallAnchor: false))
    }

    // Restore gate
    @Test func anAnchorCallbackAloneDoesNotRestoreTheWall() {
        #expect(!isWallRestored(tracking: .relocalizing, hasExpectedAnchor: true))
        #expect(!isWallRestored(tracking: .initializing, hasExpectedAnchor: true))
    }

    @Test func normalTrackingWithoutTheNamedAnchorDoesNotRestoreTheWall() {
        #expect(!isWallRestored(tracking: .normal, hasExpectedAnchor: false))
    }

    // Timeout
    @Test func relocalizationKeepsTryingUntilTheTimeout() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(!hasRelocalizationTimedOut(startedAt: start, now: start.addingTimeInterval(29.9), timeoutSeconds: relocalizationTimeoutSeconds))
        #expect(hasRelocalizationTimedOut(startedAt: start, now: start.addingTimeInterval(30), timeoutSeconds: relocalizationTimeoutSeconds))
    }

    @Test func aClockThatWentBackwardsNeverTimesOut() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(!hasRelocalizationTimedOut(startedAt: start, now: start.addingTimeInterval(-60), timeoutSeconds: relocalizationTimeoutSeconds))
    }

    // ARKit mapping
    @Test func trackingLimitsMapToReadableStatuses() {
        #expect(trackingStatus(from: .limited(.excessiveMotion)) == .movingTooFast)
        #expect(trackingStatus(from: .limited(.insufficientFeatures)) == .notEnoughDetail)
        #expect(trackingStatus(from: .limited(.initializing)) == .initializing)
        #expect(trackingStatus(from: .limited(.relocalizing)) == .relocalizing)
        #expect(trackingStatus(from: .notAvailable) == .notAvailable)
        #expect(trackingStatus(from: .normal) == .normal)
    }

    @Test func everyProblemTrackingStateHasAHint() {
        let problems: [TrackingStatus] = [.notAvailable, .initializing, .relocalizing, .movingTooFast, .notEnoughDetail, .limited]
        for status in problems {
            #expect(trackingGuidance(status) != nil)
        }
        #expect(trackingGuidance(.normal) == nil)
    }

    @Test func eachMappingStateHasItsOwnGuidance() {
        let texts = [MappingStatus.notAvailable, .limited, .extending, .mapped].map(mappingGuidance)
        #expect(Set(texts).count == 4)
    }

    // Map archive
    @Test func aSavedMapWithTheNamedAnchorComesBack() throws {
        let map = ARWorldMap()
        map.anchors = [ARAnchor(name: "wall-1", transform: matrix_identity_float4x4)]
        let data = try encodeWorldMap(map)
        let decoded = try decodeWorldMap(data, expectedAnchorName: "wall-1")
        #expect(decoded.anchors.contains { $0.name == "wall-1" })
    }

    @Test func aMapWithAnotherAnchorNameIsRejected() throws {
        let map = ARWorldMap()
        map.anchors = [ARAnchor(name: "other-wall", transform: matrix_identity_float4x4)]
        let data = try encodeWorldMap(map)
        #expect(throws: WorldMapArchiveError.missingWallAnchor) {
            try decodeWorldMap(data, expectedAnchorName: "wall-1")
        }
    }

    @Test func aMapWithNoAnchorsIsRejected() throws {
        let data = try encodeWorldMap(ARWorldMap())
        #expect(throws: WorldMapArchiveError.missingWallAnchor) {
            try decodeWorldMap(data, expectedAnchorName: "wall-1")
        }
    }

    @Test func emptyDataIsCorruptNotCrashing() {
        #expect(throws: WorldMapArchiveError.corrupt) {
            try decodeWorldMap(Data(), expectedAnchorName: "wall-1")
        }
    }

    @Test func dataExactlyAtTheLimitIsCheckedNotRefusedForSize() {
        #expect(throws: WorldMapArchiveError.corrupt) {
            try decodeWorldMap(Data(count: maximumWorldMapBytes), expectedAnchorName: "wall-1")
        }
    }

    @Test func archiveErrorsHaveDistinctMessages() {
        let errors: [WorldMapArchiveError] = [.exportFailed, .tooLarge, .corrupt, .missingWallAnchor]
        let messages = errors.map { worldMapErrorMessage($0) }
        #expect(Set(messages).count == 4)
        #expect(worldMapErrorMessage(WorldMapArchiveError.tooLarge).contains("20.0 MB"))
    }

    @Test func unknownErrorsGetAGenericMessage() {
        struct Unknown: Error {}
        #expect(worldMapErrorMessage(Unknown()) == "AR stopped unexpectedly. Try again.")
    }

    @Test func cameraDeniedHasItsOwnMessage() {
        let error = ARError(.cameraUnauthorized)
        #expect(worldMapErrorMessage(error).contains("camera"))
    }

    // Map chunks
    @Test func chunksArrivingOutOfOrderJoinInOrder() {
        let chunks: [(index: Int, data: Data)] = [(2, Data([5, 6])), (0, Data([1, 2])), (1, Data([3, 4]))]
        #expect(joinedMapData(chunks: chunks, expectedCount: 3) == Data([1, 2, 3, 4, 5, 6]))
    }

    @Test func aMissingChunkMakesTheMapUnusable() {
        let chunks: [(index: Int, data: Data)] = [(0, Data([1])), (2, Data([3]))]
        #expect(joinedMapData(chunks: chunks, expectedCount: 3) == nil)
        #expect(joinedMapData(chunks: [(0, Data([1]))], expectedCount: 2) == nil)
    }

    @Test func aDuplicatedChunkIndexIsRejected() {
        let chunks: [(index: Int, data: Data)] = [(0, Data([1])), (0, Data([1])), (1, Data([2]))]
        #expect(joinedMapData(chunks: chunks, expectedCount: 2) == nil)
    }

    @Test func splittingHandlesEmptyDataAndBadSizes() {
        #expect(splitIntoChunks(Data(), chunkSize: 10).isEmpty)
        #expect(splitIntoChunks(Data([1, 2, 3]), chunkSize: 0).isEmpty)
        #expect(splitIntoChunks(Data(count: 20), chunkSize: 10).count == 2)
        #expect(splitIntoChunks(Data(count: 21), chunkSize: 10).count == 3)
    }

    @Test func aMaximumSizeMapFitsTheChunkLimit() {
        let chunks = splitIntoChunks(Data(count: maximumWorldMapBytes), chunkSize: mapChunkByteLimit)
        #expect(chunks.count <= 24)
        #expect(chunks.allSatisfy { $0.count <= mapChunkByteLimit })
    }

    // Checksum
    @Test func anyChangedByteChangesTheChecksum() {
        let original = Data([1, 2, 3, 4])
        var changed = original
        changed[2] = 9
        #expect(sha256Hex(original) != sha256Hex(changed))
        #expect(sha256Hex(original) == sha256Hex(original))
    }

    @Test func emptyDataHasTheKnownChecksum() {
        #expect(sha256Hex(Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
}
