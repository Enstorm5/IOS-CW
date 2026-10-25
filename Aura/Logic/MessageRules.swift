import Foundation

let maximumMessageLength = 140
let messagePlacementMargin = 0.1

func messageValidationError(_ text: String) -> String? {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.isEmpty { return "Write a message first." }
    if cleaned.count > maximumMessageLength { return "Keep it to \(maximumMessageLength) characters or fewer." }
    return nil
}

func characterCountText(_ text: String) -> String {
    "\(text.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(maximumMessageLength)"
}

func isOverMessageLength(_ text: String) -> Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).count > maximumMessageLength
}

func stableHash(_ text: String) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 1_099_511_628_211
    }
    return hash
}

func messagePlacement(forMessageID messageID: String) -> (x: Double, y: Double) {
    let hash = stableHash(messageID)
    let usableRange = 1 - 2 * messagePlacementMargin
    let x = messagePlacementMargin + usableRange * Double(hash % 1000) / 999
    let y = messagePlacementMargin + usableRange * Double((hash / 1000) % 1000) / 999
    return (x, y)
}

func messageIDForPost(text: String, color: MessageColor, previous: PendingPost?, makeID: () -> String) -> String {
    if let previous, previous.text == text, previous.color == color {
        return previous.id
    }
    return makeID()
}

struct PendingPost: Equatable {
    let id: String
    let text: String
    let color: MessageColor
}
