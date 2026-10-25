import Foundation
import FirebaseFirestore

struct MessageCursor {
    fileprivate let lastDocument: DocumentSnapshot
}

struct MessagePage {
    let messages: [WallMessage]
    let nextCursor: MessageCursor?
}

final class WallMessageService {
    private let database = Firestore.firestore()
    private let pageSize = 20

    func fetchMessages(wallID: String, after cursor: MessageCursor?) async throws -> MessagePage {
        var query = activeMessages(wallID: wallID)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
        if let cursor {
            query = query.start(afterDocument: cursor.lastDocument)
        }

        let snapshot = try await query.getDocuments()
        let messages = snapshot.documents.compactMap { document in
            wallMessage(id: document.documentID, wallID: wallID, fields: fieldsWithDates(document.data()))
        }
        let hasMorePages = snapshot.documents.count == pageSize
        let nextCursor = hasMorePages ? snapshot.documents.last.map { MessageCursor(lastDocument: $0) } : nil
        return MessagePage(messages: messages, nextCursor: nextCursor)
    }

    func fetchTeaser(wallID: String) async throws -> WallTeaser {
        let countSnapshot = try await activeMessages(wallID: wallID).count.getAggregation(source: .server)
        let latestSnapshot = try await activeMessages(wallID: wallID)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        let latest = latestSnapshot.documents.first.flatMap { document in
            wallMessage(id: document.documentID, wallID: wallID, fields: fieldsWithDates(document.data()))
        }
        return WallTeaser(messageCount: countSnapshot.count.intValue, latestMessage: latest)
    }

    private func activeMessages(wallID: String) -> Query {
        database.collection("walls").document(wallID).collection("messages")
            .whereField("moderationStatus", isEqualTo: "active")
    }

    private func fieldsWithDates(_ fields: [String: Any]) -> [String: Any] {
        var converted = fields
        for (key, value) in fields {
            if let timestamp = value as? Timestamp {
                converted[key] = timestamp.dateValue()
            }
        }
        return converted
    }
}

func wallMessage(id: String, wallID: String, fields: [String: Any]) -> WallMessage? {
    guard let authorID = fields["authorID"] as? String,
          let text = fields["text"] as? String,
          let createdAt = fields["createdAt"] as? Date else { return nil }

    return WallMessage(
        id: id,
        wallID: wallID,
        authorID: authorID,
        authorName: fields["authorName"] as? String ?? "Explorer",
        text: text,
        color: MessageColor(rawValue: fields["color"] as? String ?? "") ?? .magenta,
        sparkCount: max(0, fields["sparkCount"] as? Int ?? 0),
        createdAt: createdAt
    )
}
