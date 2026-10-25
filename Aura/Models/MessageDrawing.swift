import Foundation

enum MessageContentType: String, Codable {
    case text
    case drawing
}

enum StrokeWidth: String, Codable, CaseIterable {
    case thin
    case medium
    case thick

    var fractionOfWidth: Double {
        switch self {
        case .thin: 0.01
        case .medium: 0.02
        case .thick: 0.035
        }
    }

    var title: String {
        switch self {
        case .thin: "Thin"
        case .medium: "Medium"
        case .thick: "Thick"
        }
    }
}

struct DrawingPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

struct DrawingStroke: Codable, Equatable {
    var color: MessageColor
    var width: StrokeWidth
    var points: [DrawingPoint]
}

struct MessageDrawing: Codable, Equatable {
    var strokes: [DrawingStroke] = []
}

enum MessageContent: Equatable {
    case text(String, MessageColor)
    case drawing(MessageDrawing)
}

struct PreparedMessage: Equatable {
    let text: String
    let color: MessageColor
    let contentType: MessageContentType
    let drawingPayload: String?

    var retryKey: String { drawingPayload ?? text }
}
