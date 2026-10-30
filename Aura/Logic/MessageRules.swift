import Foundation

let maximumMessageLength = 140
let messagePlacementMargin = 0.1
let messageMoveMargin = 0.05

// Message check
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

// Stable hash
func stableHash(_ text: String) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 1_099_511_628_211
    }
    return hash
}

// Position on wall
func messagePlacement(forMessageID messageID: String) -> (x: Double, y: Double) {
    let hash = stableHash(messageID)
    let usableRange = 1 - 2 * messagePlacementMargin
    let x = messagePlacementMargin + usableRange * Double(hash % 1000) / 999
    let y = messagePlacementMargin + usableRange * Double((hash / 1000) % 1000) / 999
    return (x, y)
}

// Retry-safe ID
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

// Spark rules
func sparkDocumentID(wallID: String, messageID: String) -> String {
    "\(wallID)_\(messageID)"
}

func canSpark(_ message: WallMessage, userID: String) -> Bool {
    message.authorID != userID
}

func canEdit(_ message: WallMessage, userID: String) -> Bool {
    message.authorID == userID && message.contentType == .text
}

// Move permission
func canMove(_ message: WallMessage, userID: String) -> Bool {
    message.authorID == userID
}

// Keep on wall
func clampedPlacement(_ value: Double) -> Double {
    let clamped = min(1 - messageMoveMargin, max(messageMoveMargin, value))
    return (clamped * 1000).rounded() / 1000
}

// Drag to position
func movedPlacement(start: (x: Double, y: Double), translation: CGSize, canvas: CGSize) -> (x: Double, y: Double) {
    guard canvas.width > 0, canvas.height > 0 else { return start }
    return (
        clampedPlacement(start.x + Double(translation.width / canvas.width)),
        clampedPlacement(start.y + Double(translation.height / canvas.height))
    )
}

func canDelete(_ message: WallMessage, userID: String) -> Bool {
    message.authorID == userID
}

func sparkCountAfterToggle(_ count: Int, isAddingSpark: Bool) -> Int {
    isAddingSpark ? count + 1 : max(0, count - 1)
}
