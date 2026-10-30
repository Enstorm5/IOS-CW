import Foundation
import CoreGraphics

// Drawing limits
let maximumDrawingStrokes = 60
let maximumDrawingPoints = 2_000
let maximumDrawingPayloadCharacters = 40_000
let minimumDrawingPointSpacing = 0.004
let drawingAspectRatio = 4.0 / 3.0

let neonGlowLayers: [(widthScale: Double, opacity: Double)] = [(3.2, 0.18), (2.2, 0.3), (1.4, 0.5)]
let neonCoreWidthScale = 0.45

func normalizedDrawingPoint(_ location: CGPoint, in size: CGSize) -> DrawingPoint {
    guard size.width > 0, size.height > 0 else { return DrawingPoint(x: 0, y: 0) }
    let x = min(1, max(0, Double(location.x / size.width)))
    let y = min(1, max(0, Double(location.y / size.height)))
    return DrawingPoint(x: (x * 1000).rounded() / 1000, y: (y * 1000).rounded() / 1000)
}

// Skip close points
func addingPoint(_ point: DrawingPoint, to stroke: DrawingStroke) -> DrawingStroke {
    if let last = stroke.points.last {
        let distance = ((point.x - last.x) * (point.x - last.x) + (point.y - last.y) * (point.y - last.y)).squareRoot()
        if distance < minimumDrawingPointSpacing { return stroke }
    }
    var updated = stroke
    updated.points.append(point)
    return updated
}

func drawingPointCount(_ drawing: MessageDrawing) -> Int {
    drawing.strokes.reduce(0) { $0 + $1.points.count }
}

// Size limits
func drawingValidationError(_ drawing: MessageDrawing) -> String? {
    if drawing.strokes.isEmpty || drawingPointCount(drawing) == 0 { return "Draw something first." }
    if drawing.strokes.count > maximumDrawingStrokes || drawingPointCount(drawing) > maximumDrawingPoints {
        return "This drawing is too detailed. Try fewer or shorter strokes."
    }
    return nil
}

// Drawing to JSON
func encodeDrawing(_ drawing: MessageDrawing) -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    guard let data = try? encoder.encode(drawing),
          let payload = String(data: data, encoding: .utf8),
          payload.count <= maximumDrawingPayloadCharacters else { return nil }
    return payload
}

// Safe decode
func decodeDrawing(_ payload: String) -> MessageDrawing? {
    guard payload.count <= maximumDrawingPayloadCharacters,
          let drawing = try? JSONDecoder().decode(MessageDrawing.self, from: Data(payload.utf8)),
          drawingValidationError(drawing) == nil else { return nil }
    let clamped = drawing.strokes.map { stroke in
        DrawingStroke(color: stroke.color, width: stroke.width, brush: stroke.brush, points: stroke.points.map {
            DrawingPoint(x: min(1, max(0, $0.x)), y: min(1, max(0, $0.y)))
        })
    }
    return MessageDrawing(strokes: clamped)
}

func drawingCardColor(for drawing: MessageDrawing) -> MessageColor {
    drawing.strokes.first?.color ?? .ink
}

// Validate message
func preparedMessage(from content: MessageContent) throws -> PreparedMessage {
    switch content {
    case .text(let text, let color):
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = messageValidationError(cleaned) { throw UserFacingError(message: error) }
        return PreparedMessage(text: cleaned, color: color, contentType: .text, drawingPayload: nil)
    case .drawing(let drawing):
        if let error = drawingValidationError(drawing) { throw UserFacingError(message: error) }
        guard let payload = encodeDrawing(drawing) else {
            throw UserFacingError(message: "This drawing is too detailed. Try fewer or shorter strokes.")
        }
        return PreparedMessage(text: "", color: drawingCardColor(for: drawing), contentType: .drawing, drawingPayload: payload)
    }
}

func messageAccessibilityLabel(_ message: WallMessage, isMine: Bool) -> String {
    let author = isMine ? "You" : message.authorName
    let sparks = "\(message.sparkCount) sparks."
    if message.contentType == .drawing {
        return "\(author) drew a picture. \(sparks)"
    }
    return "\(author) wrote \(message.text). \(sparks)"
}
