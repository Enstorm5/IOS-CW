import Foundation
import FirebaseFirestore

final class AccountDeletionService {
    private let database = Firestore.firestore()

    func deleteContent(userID: String) async throws {
        let messages = try await database.collectionGroup("messages")
            .whereField("authorID", isEqualTo: userID)
            .getDocuments()
        for message in messages.documents {
            try await message.reference.delete()
        }

        let walls = try await database.collection("walls")
            .whereField("ownerID", isEqualTo: userID)
            .whereField("visibility", isEqualTo: "public")
            .whereField("moderationStatus", isEqualTo: "active")
            .getDocuments()
        for wall in walls.documents {
            let chunks = try await wall.reference.collection("mapChunks").getDocuments()
            for chunk in chunks.documents {
                try await chunk.reference.delete()
            }
            try await wall.reference.delete()
        }

        try await database.collection("profiles").document(userID).delete()
    }
}
