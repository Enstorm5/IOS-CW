import Testing
import Foundation
@testable import Aura

@MainActor
struct GeoExtraTests {
    let colomboSeven = Coordinate(latitude: 6.9110, longitude: 79.8640)

    @Test func cellsShrinkAsPrecisionGrows() {
        var previous = geohashCellSizeDegrees(precision: 1)
        for precision in 2...9 {
            let cell = geohashCellSizeDegrees(precision: precision)
            #expect(cell.latitude < previous.latitude)
            #expect(cell.longitude < previous.longitude)
            previous = cell
        }
    }

    @Test func precisionMatchesTheSearchRadius() {
        let small = geohashSearchPrecision(center: colomboSeven, radiusMeters: 50)
        let large = geohashSearchPrecision(center: colomboSeven, radiusMeters: 5_000)
        #expect(small > large)
        #expect(geohashSearchPrecision(center: colomboSeven, radiusMeters: 20_000_000) == 1)
    }

    @Test func offsetsScaleWithRadius() {
        let near = searchOffsetsDegrees(center: colomboSeven, radiusMeters: 500)
        let far = searchOffsetsDegrees(center: colomboSeven, radiusMeters: 1_000)
        #expect(abs(far.latitude - near.latitude * 2) < 1e-9)
        #expect(near.longitude > near.latitude)
    }

    @Test func geohashHasTheRequestedLength() {
        for precision in [1, 5, 9, 12] {
            #expect(geohash(for: colomboSeven, precision: precision).count == precision)
        }
        #expect(geohash(for: colomboSeven, precision: 9).hasPrefix(geohash(for: colomboSeven, precision: 5)))
    }

    @Test func sameWallTwiceIsReturnedOnce() {
        let wall = Wall(id: "w", title: "W", coordinate: colomboSeven, kind: .community)
        #expect(wallsWithinRadius(from: [wall, wall], center: colomboSeven, radiusMeters: 10).count == 1)
        #expect(wallsWithinRadius(from: [], center: colomboSeven, radiusMeters: 10).isEmpty)
    }

    @Test func tiesSortByID() {
        let a = Wall(id: "a", title: "A", coordinate: colomboSeven, kind: .community)
        let b = Wall(id: "b", title: "B", coordinate: colomboSeven, kind: .community)
        #expect(wallsWithinRadius(from: [b, a], center: colomboSeven, radiusMeters: 10).map(\.id) == ["a", "b"])
    }
}
