import Foundation

enum MessageColor: String, CaseIterable {
    case magenta
    case mint
    case yellow
    case ink

    var title: String {
        switch self {
        case .magenta: "Magenta"
        case .mint: "Mint"
        case .yellow: "Yellow"
        case .ink: "Ink"
        }
    }
}

struct NewWallMessage: Equatable {
    let id: String
    let wallID: String
    let authorID: String
    let authorName: String
    let text: String
    let color: MessageColor
    let normalizedX: Double
    let normalizedY: Double
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
    var normalizedX: Double = 0.5
    var normalizedY: Double = 0.5
}
