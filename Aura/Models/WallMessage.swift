import Foundation

enum MessageColor: String, CaseIterable {
    case magenta
    case mint
    case yellow
    case ink
}

struct WallTeaser: Equatable {
    let messageCount: Int
    let latestMessage: WallMessage?
}

struct WallMessage: Identifiable, Equatable {
    var id: String
    var wallID: String
    var authorID: String
    var authorName: String
    var text: String
    var color: MessageColor
    var sparkCount: Int
    var createdAt: Date
}
