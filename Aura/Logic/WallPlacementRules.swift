import Foundation
import CryptoKit

struct WallSize: Hashable, Codable {
    var width: Double
    var height: Double
}

let defaultWallSize = WallSize(width: 1.2, height: 0.8)
let minimumWallSideMeters = 0.5
let maximumWallSideMeters = 3.0
let wallSizeStepMeters = 0.1
let wallTitleLengthRange = 2...40
let firstMapVersion = 1
let wallGeohashPrecision = 9
let maximumMessagesOnARWall = 20

// Size limits
func clampedWallSide(_ meters: Double) -> Double {
    let clamped = min(maximumWallSideMeters, max(minimumWallSideMeters, meters))
    return (clamped * 10).rounded() / 10
}

func clampedWallSize(_ size: WallSize) -> WallSize {
    WallSize(width: clampedWallSide(size.width), height: clampedWallSide(size.height))
}

// Pinch resize
func resizedWallSize(start: WallSize, pinchScale: Double) -> WallSize {
    guard pinchScale.isFinite, pinchScale > 0 else { return clampedWallSize(start) }
    return clampedWallSize(WallSize(width: start.width * pinchScale, height: start.height * pinchScale))
}

func steppedWallSize(_ size: WallSize, widthSteps: Int, heightSteps: Int) -> WallSize {
    clampedWallSize(WallSize(
        width: size.width + Double(widthSteps) * wallSizeStepMeters,
        height: size.height + Double(heightSteps) * wallSizeStepMeters
    ))
}

func wallSizeText(_ size: WallSize) -> String {
    String(format: "%.1f × %.1f m", size.width, size.height)
}

func wallTitleValidationError(_ title: String) -> String? {
    let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.isEmpty { return "Give your wall a name." }
    if cleaned.count < wallTitleLengthRange.lowerBound { return "Use at least \(wallTitleLengthRange.lowerBound) characters." }
    if cleaned.count > wallTitleLengthRange.upperBound { return "Use \(wallTitleLengthRange.upperBound) characters or fewer." }
    return nil
}

let firestoreChunkStorage = "firestoreChunks"
let mapChunkByteLimit = 900_000

// Split map data
func splitIntoChunks(_ data: Data, chunkSize: Int) -> [Data] {
    guard chunkSize > 0, !data.isEmpty else { return [] }
    return stride(from: 0, to: data.count, by: chunkSize).map { start in
        data.subdata(in: start..<min(start + chunkSize, data.count))
    }
}

// Join map chunks
func joinedMapData(chunks: [(index: Int, data: Data)], expectedCount: Int) -> Data? {
    let sorted = chunks.sorted { $0.index < $1.index }
    guard sorted.count == expectedCount,
          sorted.map(\.index) == Array(0..<expectedCount) else { return nil }
    return sorted.reduce(into: Data()) { $0.append($1.data) }
}

// Checksum
func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

// Publish location
func publishLocationError(access: LocationAccess, fix: LocationFix?, now: Date) -> String? {
    switch access {
    case .notAsked, .denied, .restricted:
        return "Turn on location to publish a wall. It sets where the wall appears on the map."
    case .allowed(let isPrecise):
        if !isPrecise { return "Turn on Precise Location to publish a wall." }
    }

    guard let fix,
          fix.horizontalAccuracyMeters >= 0,
          fix.horizontalAccuracyMeters <= wallPostingPolicy.maximumAccuracyMeters,
          now.timeIntervalSince(fix.timestamp) <= wallPostingPolicy.maximumAgeSeconds else {
        return "Waiting for an accurate location fix. Try again in a moment."
    }
    return nil
}

// Text orientation
func canvasNeedsFlip(anchorZAxisWorldY: Float) -> Bool {
    anchorZAxisWorldY > 0
}

// Wall position
func messageCanvasPosition(normalizedX: Double, normalizedY: Double, size: WallSize) -> (x: Float, z: Float) {
    let x = min(1, max(0, normalizedX))
    let y = min(1, max(0, normalizedY))
    return (Float((x - 0.5) * size.width), Float((y - 0.5) * size.height))
}

func renamedWalls(_ walls: [Wall], wallID: String, title: String) -> [Wall] {
    walls.map { wall in
        guard wall.id == wallID else { return wall }
        var renamed = wall
        renamed.title = title
        return renamed
    }
}

func myWallDetail(_ wall: Wall) -> String {
    guard let map = wall.map else { return "No AR map" }
    return "\(wallSizeText(map.size)) · \(formattedByteCount(map.byteCount)) map"
}
