import Testing
import Foundation
@testable import Aura

@MainActor
struct ModelMappingTests {
    let mapFields: [String: Any] = [
        "anchorMode": "worldMap", "mapStorage": "firestoreChunks", "mapChunkCount": 2, "activeMapVersion": 1,
        "mapChecksum": String(repeating: "b", count: 64), "mapByteCount": 1_200_000, "anchorName": "w1",
        "widthMeters": 9.0, "heightMeters": 0.1,
    ]

    @Test func wallOwnerIsReadFromTheDocumentAndChecked() {
        let owned = wall(id: "w", fields: ["title": "T", "latitude": 6.9, "longitude": 79.8, "ownerID": "u1"])
        #expect(owned?.ownerID == "u1")
        #expect(isWallOwner(owned!, userID: "u1"))
        #expect(!isWallOwner(owned!, userID: "u2"))
        let unknown = wall(id: "w", fields: ["title": "T", "latitude": 6.9, "longitude": 79.8])
        #expect(unknown?.ownerID == nil)
        #expect(!isWallOwner(unknown!, userID: "u1"))
    }

    @Test func mapSizesAreClampedWhenRead() {
        let info = wallMapInfo(fields: mapFields)
        #expect(info?.size == WallSize(width: 3, height: 0.5))
        #expect(info?.chunkCount == 2)
    }

    @Test func mapInfoNeedsEveryField() {
        for key in ["mapChunkCount", "activeMapVersion", "mapChecksum", "mapByteCount", "anchorName", "widthMeters", "heightMeters"] {
            var fields = mapFields
            fields.removeValue(forKey: key)
            #expect(wallMapInfo(fields: fields) == nil, "missing \(key)")
        }
        var other = mapFields
        other["mapStorage"] = "storage"
        #expect(wallMapInfo(fields: other) == nil)
        other = mapFields
        other["anchorMode"] = "image"
        #expect(wallMapInfo(fields: other) == nil)
    }

    @Test func wallsNeedTitleAndCoordinates() {
        #expect(wall(id: "w", fields: ["latitude": 6.9, "longitude": 79.8]) == nil)
        #expect(wall(id: "w", fields: ["title": "T", "longitude": 79.8]) == nil)
        #expect(wall(id: "w", fields: ["title": "T", "latitude": 6.9]) == nil)
    }

    @Test func profilesSkipUnknownValues() {
        let fields: [String: Any] = ["displayName": "Nimal", "bio": "hi", "avatarPreset": "night", "interests": ["parks", "unknown", "cafes"]]
        let profile = userProfile(id: "u", fields: fields)
        #expect(profile?.interests == [.parks, .cafes])
        #expect(profile?.avatarPreset == .night)
        #expect(firestoreFields(for: profile!)["interests"] as? [String] == ["parks", "cafes"])
    }

    @Test func messageDefaultsAreSafe() {
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        let message = wallMessage(id: "m", wallID: "w", fields: ["authorID": "a", "text": "hi", "createdAt": created, "normalizedX": 7.0, "normalizedY": -3.0])
        #expect(message?.normalizedX == 1 && message?.normalizedY == 0)
        #expect(message?.contentType == .text)
        #expect(message?.authorName == "Explorer")
    }

    @Test func everyInterestAndAvatarHasATitle() {
        #expect(Interest.allCases.count == 8 && Interest.allCases.allSatisfy { !$0.title.isEmpty })
        #expect(AvatarPreset.allCases.count == 4 && AvatarPreset.allCases.allSatisfy { !$0.title.isEmpty })
        #expect(MessageColor.allCases.map(\.title) == ["Magenta", "Mint", "Yellow", "Ink"])
        #expect(StrokeWidth.allCases.map(\.title) == ["Thin", "Medium", "Thick"])
    }
}
