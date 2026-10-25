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

struct Wall: Identifiable, Hashable {
    var id: String
    var title: String
    var coordinate: Coordinate
    var kind: WallKind
}

struct NearbyWall: Identifiable, Equatable {
    let wall: Wall
    let distanceMeters: Double

    var id: String { wall.id }
}
