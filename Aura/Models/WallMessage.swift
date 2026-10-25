import Foundation

enum MessageColor: String, CaseIterable {
    case magenta
    case mint
    case yellow
    case ink
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
