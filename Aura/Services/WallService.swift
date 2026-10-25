import Foundation
import FirebaseFirestore

final class WallService {
    private let walls = Firestore.firestore().collection("walls")
    private let maximumWallsPerRange = 50

    func fetchPublicWalls(near center: Coordinate, radiusMeters: Double) async throws -> [NearbyWall] {
        var found: [Wall] = []
        for range in geohashQueryRanges(center: center, radiusMeters: radiusMeters) {
            let snapshot = try await walls
                .whereField("visibility", isEqualTo: "public")
                .whereField("moderationStatus", isEqualTo: "active")
                .order(by: "geohash")
                .start(at: [range.start])
                .end(at: [range.end])
                .limit(to: maximumWallsPerRange)
                .getDocuments()
            found += snapshot.documents.compactMap { wall(id: $0.documentID, fields: $0.data()) }
        }
        return nearbyWalls(from: found, center: center, radiusMeters: radiusMeters)
    }
}

func wall(id: String, fields: [String: Any]) -> Wall? {
    guard let title = fields["title"] as? String,
          let latitude = fields["latitude"] as? Double,
          let longitude = fields["longitude"] as? Double else { return nil }

    return Wall(
        id: id,
        title: title,
        coordinate: Coordinate(latitude: latitude, longitude: longitude),
        kind: WallKind(rawValue: fields["kind"] as? String ?? "") ?? .community
    )
}
