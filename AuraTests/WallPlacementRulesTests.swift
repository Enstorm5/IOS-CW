import Testing
import Foundation
@testable import Aura

@MainActor
struct WallPlacementRulesTests {

    @Test func sizesStayWithinLimitsAndRoundToTenCentimetres() {
        #expect(clampedWallSize(WallSize(width: 0.2, height: 5)) == WallSize(width: 0.5, height: 3))
        #expect(clampedWallSize(WallSize(width: 1.234, height: 0.86)) == WallSize(width: 1.2, height: 0.9))
    }

    @Test func pinchScalesBothSides() {
        #expect(resizedWallSize(start: WallSize(width: 1.2, height: 0.8), pinchScale: 2) == WallSize(width: 2.4, height: 1.6))
        #expect(resizedWallSize(start: WallSize(width: 1.2, height: 0.8), pinchScale: 10) == WallSize(width: 3, height: 3))
        #expect(resizedWallSize(start: WallSize(width: 1.2, height: 0.8), pinchScale: 0) == WallSize(width: 1.2, height: 0.8))
    }

    @Test func steppersMoveByTenCentimetres() {
        #expect(steppedWallSize(WallSize(width: 1.2, height: 0.8), widthSteps: 1, heightSteps: -1) == WallSize(width: 1.3, height: 0.7))
        #expect(steppedWallSize(WallSize(width: 0.5, height: 3), widthSteps: -1, heightSteps: 1) == WallSize(width: 0.5, height: 3))
        #expect(wallSizeText(WallSize(width: 1.2, height: 0.8)) == "1.2 × 0.8 m")
    }

    @Test func titleNeedsTwoToFortyCharacters() {
        #expect(wallTitleValidationError("  ") != nil)
        #expect(wallTitleValidationError("A") != nil)
        #expect(wallTitleValidationError(" Library steps ") == nil)
        #expect(wallTitleValidationError(String(repeating: "x", count: 41)) != nil)
    }

    @Test func chunksJoinBackToTheSameBytes() {
        let data = Data((0..<2_500).map { UInt8($0 % 251) })
        let chunks = splitIntoChunks(data, chunkSize: 1_000)
        #expect(chunks.map(\.count) == [1_000, 1_000, 500])

        let shuffled = [(index: 2, data: chunks[2]), (index: 0, data: chunks[0]), (index: 1, data: chunks[1])]
        #expect(joinedMapData(chunks: shuffled, expectedCount: 3) == data)
        #expect(joinedMapData(chunks: Array(shuffled.prefix(2)), expectedCount: 3) == nil)
        #expect(splitIntoChunks(Data(), chunkSize: 1_000).isEmpty)
    }

    @Test func checksumMatchesKnownSHA256() {
        #expect(sha256Hex(Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func publishingNeedsPreciseFreshLocation() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fresh = LocationFix(coordinate: Coordinate(latitude: 6.9, longitude: 79.8), horizontalAccuracyMeters: 5, timestamp: now)
        let stale = LocationFix(coordinate: fresh.coordinate, horizontalAccuracyMeters: 5, timestamp: now.addingTimeInterval(-60))
        #expect(publishLocationError(access: .allowed(isPrecise: true), fix: fresh, now: now) == nil)
        #expect(publishLocationError(access: .allowed(isPrecise: true), fix: stale, now: now) != nil)
        #expect(publishLocationError(access: .allowed(isPrecise: false), fix: fresh, now: now) != nil)
        #expect(publishLocationError(access: .denied, fix: fresh, now: now) != nil)
    }

    @Test func messagesSitInsideTheWall() {
        let size = WallSize(width: 2, height: 1)
        let topLeft = messageCanvasPosition(normalizedX: 0, normalizedY: 0, size: size)
        let center = messageCanvasPosition(normalizedX: 0.5, normalizedY: 0.5, size: size)
        let outside = messageCanvasPosition(normalizedX: 4, normalizedY: -1, size: size)
        #expect(topLeft.x == -1 && topLeft.z == -0.5)
        #expect(center.x == 0 && center.z == 0)
        #expect(outside.x == 1 && outside.z == -0.5)
        #expect(canvasNeedsFlip(anchorZAxisWorldY: 0.9))
        #expect(!canvasNeedsFlip(anchorZAxisWorldY: -0.9))
    }

    @Test func publishedWallFieldsRoundTrip() {
        let draft = NewWallDraft(
            wallID: "w1", ownerID: "u1", title: "Library steps",
            coordinate: Coordinate(latitude: 6.9113, longitude: 79.8597),
            size: WallSize(width: 1.5, height: 1), mapChunkCount: 3, mapByteCount: 2_500_000,
            mapChecksum: String(repeating: "a", count: 64), captureOSVersion: "26.5"
        )
        let fields = newWallFields(for: draft)
        #expect(fields.count == 19)
        #expect(fields["geohash"] as? String == geohash(for: draft.coordinate, precision: 9))

        let parsed = wall(id: "w1", fields: fields)
        #expect(parsed?.map == WallMapInfo(chunkCount: 3, version: 1, checksum: draft.mapChecksum, byteCount: 2_500_000, anchorName: "w1", size: draft.size))
    }

    @Test func aPublishedWallCanBeOpenedStraightFromItsDraft() {
        let draft = NewWallDraft(
            wallID: "w1", ownerID: "u1", title: "Library steps",
            coordinate: Coordinate(latitude: 6.9113, longitude: 79.8597),
            size: WallSize(width: 1.5, height: 1), mapChunkCount: 3, mapByteCount: 2_500_000,
            mapChecksum: String(repeating: "a", count: 64), captureOSVersion: "26.5"
        )
        let wall = wallFromDraft(draft)
        #expect(wall.id == "w1" && wall.title == "Library steps" && wall.kind == .community)
        #expect(wall.coordinate == draft.coordinate)
        #expect(wall.ownerID == "u1" && isWallOwner(wall, userID: "u1"))
        #expect(wall.map == WallMapInfo(chunkCount: 3, version: 1, checksum: draft.mapChecksum, byteCount: 2_500_000, anchorName: "w1", size: draft.size))
    }

    @Test func demoWallsHaveNoMap() {
        #expect(wall(id: "demo", fields: ["title": "Demo", "latitude": 6.9, "longitude": 79.8])?.map == nil)
    }
}
