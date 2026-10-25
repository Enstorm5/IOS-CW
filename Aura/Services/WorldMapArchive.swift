import Foundation
import ARKit
import CoreImage

enum WorldMapArchiveError: Error, Equatable {
    case exportFailed
    case tooLarge
    case corrupt
    case missingWallAnchor
    case snapshotFailed
    case snapshotTooLarge
}

let snapshotJPEGQuality: CGFloat = 0.7

func encodeWorldMap(_ map: ARWorldMap) throws -> Data {
    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
    guard data.count <= maximumWorldMapBytes else { throw WorldMapArchiveError.tooLarge }
    return data
}

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

func snapshotJPEG(from pixelBuffer: CVPixelBuffer) throws -> Data {
    let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let data = CIContext().jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: snapshotJPEGQuality]
          ) else {
        throw WorldMapArchiveError.snapshotFailed
    }
    guard data.count <= maximumSnapshotBytes else { throw WorldMapArchiveError.snapshotTooLarge }
    return data
}

func worldMapErrorMessage(_ error: Error) -> String {
    if let archiveError = error as? WorldMapArchiveError {
        switch archiveError {
        case .exportFailed: return "ARKit couldn't export the map. Keep scanning and try again."
        case .tooLarge: return "The map is over \(formattedByteCount(maximumWorldMapBytes)). Scan a smaller area and try again."
        case .corrupt: return "The saved map is damaged. Delete it and place the wall again."
        case .missingWallAnchor: return "The saved map doesn't contain the wall. Place it again."
        case .snapshotFailed: return "Couldn't capture the guidance photo. Try again."
        case .snapshotTooLarge: return "The guidance photo is over \(formattedByteCount(maximumSnapshotBytes)). Try again."
        }
    }
    if let arError = error as? ARError, arError.code == .cameraUnauthorized {
        return "Allow camera access for Aura in Settings to use AR."
    }
    return "AR stopped unexpectedly. Try again."
}
