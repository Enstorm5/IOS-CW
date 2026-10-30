import Foundation
import ARKit

enum WorldMapArchiveError: Error, Equatable {
    case exportFailed
    case tooLarge
    case corrupt
    case missingWallAnchor
}

// Archive world map
func encodeWorldMap(_ map: ARWorldMap) throws -> Data {
    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
    guard data.count <= maximumWorldMapBytes else { throw WorldMapArchiveError.tooLarge }
    return data
}

// Safe decode
func decodeWorldMap(_ data: Data, expectedAnchorName: String) throws -> ARWorldMap {
    guard data.count <= maximumWorldMapBytes else { throw WorldMapArchiveError.tooLarge }
    guard let map = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
        throw WorldMapArchiveError.corrupt
    }
    guard map.anchors.contains(where: { $0.name == expectedAnchorName }) else {
        throw WorldMapArchiveError.missingWallAnchor
    }
    return map
}

// Readable errors
func worldMapErrorMessage(_ error: Error) -> String {
    if let archiveError = error as? WorldMapArchiveError {
        switch archiveError {
        case .exportFailed: return "ARKit couldn't export the map. Keep scanning and try again."
        case .tooLarge: return "The map is over \(formattedByteCount(maximumWorldMapBytes)). Scan a smaller area and try again."
        case .corrupt: return "The wall's map is damaged. Place the wall again."
        case .missingWallAnchor: return "The saved map doesn't contain the wall. Place it again."
        }
    }
    if let arError = error as? ARError, arError.code == .cameraUnauthorized {
        return "Allow camera access for Aura in Settings to use AR."
    }
    return "AR stopped unexpectedly. Try again."
}
