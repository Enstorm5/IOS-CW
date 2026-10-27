import Testing
import Foundation
@testable import Aura

@MainActor
struct MyWallsTests {
    let map = WallMapInfo(chunkCount: 3, version: 1, checksum: String(repeating: "a", count: 64), byteCount: 3_565_158, anchorName: "w1", size: WallSize(width: 1.2, height: 0.8))

    @Test func renameChangesOnlyThatWall() {
        let walls = [
            Wall(id: "w1", title: "Old", coordinate: Coordinate(latitude: 0, longitude: 0), kind: .community, map: map),
            Wall(id: "w2", title: "Other", coordinate: Coordinate(latitude: 0, longitude: 0), kind: .community),
        ]
        let renamed = renamedWalls(walls, wallID: "w1", title: "New")
        #expect(renamed.map(\.title) == ["New", "Other"])
        #expect(renamed[0].map == map)
        #expect(renamedWalls(walls, wallID: "missing", title: "X") == walls)
    }

    @Test func detailShowsSizeAndMapBytes() {
        let wall = Wall(id: "w1", title: "T", coordinate: Coordinate(latitude: 0, longitude: 0), kind: .community, map: map)
        #expect(myWallDetail(wall) == "1.2 × 0.8 m · 3.4 MB map")
        #expect(myWallDetail(Wall(id: "w2", title: "T", coordinate: Coordinate(latitude: 0, longitude: 0), kind: .community)) == "No AR map")
    }
}
