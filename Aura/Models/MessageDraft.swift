import Foundation

struct MessageDraft: Equatable {
    var accountID: String
    var wallID: String
    var text: String
    var color: MessageColor
    var updatedAt: Date
}

struct CachedWalls: Equatable {
    var walls: [Wall]
    var savedAt: Date?
}

struct CachedMessages: Equatable {
    var messages: [WallMessage]
    var savedAt: Date?
}
