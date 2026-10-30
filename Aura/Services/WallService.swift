import Foundation
import FirebaseFirestore

final class WallService {
    private let walls = Firestore.firestore().collection("walls")
    private let maximumWallsPerRange = 50

    // Geohash query
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
        return wallsWithinRadius(from: found, center: center, radiusMeters: radiusMeters)
    }
}

// Map wall fields
func wall(id: String, fields: [String: Any]) -> Wall? {
    guard let title = fields["title"] as? String,
          let latitude = fields["latitude"] as? Double,
          let longitude = fields["longitude"] as? Double else { return nil }

    return Wall(
        id: id,
        title: title,
        coordinate: Coordinate(latitude: latitude, longitude: longitude),
        kind: WallKind(rawValue: fields["kind"] as? String ?? "") ?? .community,
        map: wallMapInfo(fields: fields)
    )
}

func wallMapInfo(fields: [String: Any]) -> WallMapInfo? {
    guard fields["anchorMode"] as? String == "worldMap",
          fields["mapStorage"] as? String == firestoreChunkStorage,
          let chunkCount = fields["mapChunkCount"] as? Int,
          let version = fields["activeMapVersion"] as? Int,
          let checksum = fields["mapChecksum"] as? String,
          let byteCount = fields["mapByteCount"] as? Int,
          let anchorName = fields["anchorName"] as? String,
          let width = fields["widthMeters"] as? Double,
          let height = fields["heightMeters"] as? Double else { return nil }

    return WallMapInfo(
        chunkCount: chunkCount,
        version: version,
        checksum: checksum,
        byteCount: byteCount,
        anchorName: anchorName,
        size: clampedWallSize(WallSize(width: width, height: height))
    )
}

// Wall document
func newWallFields(for draft: NewWallDraft) -> [String: Any] {
    [
        "title": draft.title,
        "latitude": draft.coordinate.latitude,
        "longitude": draft.coordinate.longitude,
        "geohash": geohash(for: draft.coordinate, precision: wallGeohashPrecision),
        "kind": WallKind.community.rawValue,
        "visibility": "public",
        "moderationStatus": "active",
        "ownerID": draft.ownerID,
        "anchorMode": "worldMap",
        "anchorName": draft.wallID,
        "widthMeters": draft.size.width,
        "heightMeters": draft.size.height,
        "activeMapVersion": firstMapVersion,
        "mapStorage": firestoreChunkStorage,
        "mapChunkCount": draft.mapChunkCount,
        "mapByteCount": draft.mapByteCount,
        "mapChecksum": draft.mapChecksum,
        "archiveVersion": worldMapArchiveVersion,
        "captureOSVersion": draft.captureOSVersion,
    ]
}
