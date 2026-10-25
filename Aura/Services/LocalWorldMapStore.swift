import Foundation

struct SavedWallMetadata: Codable, Equatable {
    var wallID: String
    var savedAt: Date
    var mapByteCount: Int
    var snapshotByteCount: Int
    var osVersion: String
    var archiveVersion: Int
}

final class LocalWorldMapStore {
    private let folder: URL
    private let fileManager = FileManager.default

    private var mapURL: URL { folder.appendingPathComponent("worldmap.bin") }
    private var snapshotURL: URL { folder.appendingPathComponent("snapshot.jpg") }
    private var metadataURL: URL { folder.appendingPathComponent("metadata.json") }

    init(folder: URL = URL.applicationSupportDirectory.appendingPathComponent("ARSpike", isDirectory: true)) {
        self.folder = folder
    }

    func save(mapData: Data, snapshotData: Data, metadata: SavedWallMetadata) throws {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try mapData.write(to: mapURL, options: .atomic)
        try snapshotData.write(to: snapshotURL, options: .atomic)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(metadata).write(to: metadataURL, options: .atomic)
    }

    func loadMetadata() -> SavedWallMetadata? {
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SavedWallMetadata.self, from: data)
    }

    func loadMapData() throws -> Data {
        try Data(contentsOf: mapURL)
    }

    func loadSnapshotData() -> Data? {
        try? Data(contentsOf: snapshotURL)
    }

    func delete() throws {
        if fileManager.fileExists(atPath: folder.path()) {
            try fileManager.removeItem(at: folder)
        }
    }
}
