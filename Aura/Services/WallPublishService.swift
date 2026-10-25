import Foundation
import FirebaseFirestore

final class WallPublishService {
    private let database = Firestore.firestore()
    private let cacheFolder = URL.cachesDirectory.appendingPathComponent("WallMaps", isDirectory: true)

    func publish(_ draft: NewWallDraft, mapData: Data) async throws {
        let wallDocument = database.collection("walls").document(draft.wallID)
        let chunks = splitIntoChunks(mapData, chunkSize: mapChunkByteLimit)

        for (index, chunk) in chunks.enumerated() {
            let chunkDocument = wallDocument.collection("mapChunks").document(String(index))
            let fields: [String: Any] = [
                "index": index,
                "version": firstMapVersion,
                "ownerID": draft.ownerID,
                "data": chunk,
            ]
            try await createOwnedDocument(chunkDocument, fields: fields, ownerID: draft.ownerID)
        }

        var fields = newWallFields(for: draft)
        fields["createdAt"] = FieldValue.serverTimestamp()
        fields["updatedAt"] = FieldValue.serverTimestamp()
        try await createOwnedDocument(wallDocument, fields: fields, ownerID: draft.ownerID)
    }

    func downloadMap(wallID: String, map: WallMapInfo) async throws -> Data {
        let cacheURL = cacheFolder.appendingPathComponent("\(wallID)-v\(map.version).bin")
        if let cached = try? Data(contentsOf: cacheURL), sha256Hex(cached) == map.checksum {
            return cached
        }

        guard map.byteCount <= maximumWorldMapBytes else { throw WorldMapArchiveError.tooLarge }
        let snapshot = try await database.collection("walls").document(wallID).collection("mapChunks")
            .whereField("version", isEqualTo: map.version)
            .getDocuments()
        let chunks = snapshot.documents.compactMap { document -> (index: Int, data: Data)? in
            guard let index = document.data()["index"] as? Int,
                  let data = document.data()["data"] as? Data else { return nil }
            return (index, data)
        }

        guard let data = joinedMapData(chunks: chunks, expectedCount: map.chunkCount),
              sha256Hex(data) == map.checksum else {
            throw WorldMapArchiveError.corrupt
        }

        try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
        return data
    }

    private func createOwnedDocument(_ document: DocumentReference, fields: [String: Any], ownerID: String) async throws {
        do {
            try await document.setData(fields)
        } catch {
            let existing = try? await document.getDocument()
            guard existing?.data()?["ownerID"] as? String == ownerID else { throw error }
        }
    }
}

func wallMapErrorMessage(_ error: Error) -> String {
    if error is WorldMapArchiveError {
        return worldMapErrorMessage(error)
    }
    return "Couldn't reach the server. Check your connection and try again."
}
