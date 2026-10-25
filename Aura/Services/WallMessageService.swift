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

    func post(_ message: NewWallMessage) async throws -> WallMessage {
        let document = database.collection("walls").document(message.wallID).collection("messages").document(message.id)
        var fields = firestoreFields(for: message)
        fields["createdAt"] = FieldValue.serverTimestamp()
        fields["updatedAt"] = FieldValue.serverTimestamp()

        do {
            try await document.setData(fields)
        } catch {
            let existing = try? await document.getDocument()
            guard existing?.data()?["authorID"] as? String == message.authorID else { throw error }
        }

        return WallMessage(
            id: message.id,
            wallID: message.wallID,
            authorID: message.authorID,
            authorName: message.authorName,
            text: message.text,
            color: message.color,
            sparkCount: 0,
            createdAt: Date(),
            normalizedX: message.normalizedX,
            normalizedY: message.normalizedY,
            contentType: message.contentType,
            drawing: message.drawingPayload.flatMap(decodeDrawing)
        )
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

func firestoreFields(for message: NewWallMessage) -> [String: Any] {
    var fields: [String: Any] = [
        "authorID": message.authorID,
        "authorName": message.authorName,
        "text": message.text,
        "contentType": message.contentType.rawValue,
        "color": message.color.rawValue,
        "sparkCount": 0,
        "normalizedX": message.normalizedX,
        "normalizedY": message.normalizedY,
        "moderationStatus": "active",
    ]
    if let drawingPayload = message.drawingPayload {
        fields["drawing"] = drawingPayload
    }
    return fields
}

func wallMessage(id: String, wallID: String, fields: [String: Any]) -> WallMessage? {
    guard let authorID = fields["authorID"] as? String,
          let text = fields["text"] as? String,
          let createdAt = fields["createdAt"] as? Date else { return nil }

    let contentType = MessageContentType(rawValue: fields["contentType"] as? String ?? "") ?? .text
    var drawing: MessageDrawing?
    if contentType == .drawing {
        guard let payload = fields["drawing"] as? String, let decoded = decodeDrawing(payload) else { return nil }
        drawing = decoded
    }

    return WallMessage(
        id: id,
        wallID: wallID,
        authorID: authorID,
        authorName: fields["authorName"] as? String ?? "Explorer",
        text: text,
        color: MessageColor(rawValue: fields["color"] as? String ?? "") ?? .magenta,
        sparkCount: max(0, fields["sparkCount"] as? Int ?? 0),
        createdAt: createdAt,
        normalizedX: min(1, max(0, fields["normalizedX"] as? Double ?? 0.5)),
        normalizedY: min(1, max(0, fields["normalizedY"] as? Double ?? 0.5)),
        contentType: contentType,
        drawing: drawing
    )
}
