import Foundation
import CoreLocation

struct Coordinate: Hashable {
    var latitude: Double
    var longitude: Double
}

extension Coordinate {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum WallKind: String {
    case community
    case sponsored
}

// AR map details
struct WallMapInfo: Hashable, Codable {
    var chunkCount: Int
    var version: Int
    var checksum: String
    var byteCount: Int
    var anchorName: String
    var size: WallSize
}

// Wall data
struct Wall: Identifiable, Hashable {
    var id: String
    var title: String
    var coordinate: Coordinate
    var kind: WallKind
    var map: WallMapInfo? = nil
    var ownerID: String? = nil
}

// Wall to publish
struct NewWallDraft: Equatable {
    let wallID: String
    let ownerID: String
    let title: String
    let coordinate: Coordinate
    let size: WallSize
    let mapChunkCount: Int
    let mapByteCount: Int
    let mapChecksum: String
    let captureOSVersion: String
}

struct NearbyWall: Identifiable, Equatable {
    let wall: Wall
    let distanceMeters: Double

    var id: String { wall.id }
}
