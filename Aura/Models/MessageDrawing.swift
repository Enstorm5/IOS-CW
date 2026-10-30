import Foundation

enum MessageContentType: String, Codable {
    case text
    case drawing
}

// Stroke widths
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

// Brush types
enum StrokeBrush: String, Codable, CaseIterable {
    case marker
    case neon

    var title: String {
        switch self {
        case .marker: "Marker"
        case .neon: "Neon"
        }
    }
}

// One stroke
struct DrawingStroke: Codable, Equatable {
    var color: MessageColor
    var width: StrokeWidth
    var brush: StrokeBrush = .marker
    var points: [DrawingPoint]
}

extension DrawingStroke {
    enum CodingKeys: String, CodingKey {
        case color, width, brush, points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decode(MessageColor.self, forKey: .color)
        width = try container.decode(StrokeWidth.self, forKey: .width)
        brush = try container.decodeIfPresent(StrokeBrush.self, forKey: .brush) ?? .marker
        points = try container.decode([DrawingPoint].self, forKey: .points)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(color, forKey: .color)
        try container.encode(width, forKey: .width)
        if brush != .marker {
            try container.encode(brush, forKey: .brush)
        }
        try container.encode(points, forKey: .points)
    }
}

// Whole drawing
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
