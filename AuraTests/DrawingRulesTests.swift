import Testing
import Foundation
import CoreGraphics
@testable import Aura

@MainActor
struct DrawingRulesTests {
    let squiggle = MessageDrawing(strokes: [
        DrawingStroke(color: .mint, width: .medium, points: [DrawingPoint(x: 0.1, y: 0.1), DrawingPoint(x: 0.5, y: 0.6)]),
        DrawingStroke(color: .ink, width: .thick, points: [DrawingPoint(x: 0.7, y: 0.2)]),
    ])

    @Test func pointsAreClampedAndRounded() {
        let size = CGSize(width: 400, height: 300)
        #expect(normalizedDrawingPoint(CGPoint(x: 200, y: 150), in: size) == DrawingPoint(x: 0.5, y: 0.5))
        #expect(normalizedDrawingPoint(CGPoint(x: -20, y: 900), in: size) == DrawingPoint(x: 0, y: 1))
        #expect(normalizedDrawingPoint(CGPoint(x: 1, y: 1), in: size) == DrawingPoint(x: 0.003, y: 0.003))
        #expect(normalizedDrawingPoint(CGPoint(x: 1, y: 1), in: .zero) == DrawingPoint(x: 0, y: 0))
    }

    @Test func pointsTooCloseTogetherAreSkipped() {
        let stroke = DrawingStroke(color: .ink, width: .thin, points: [DrawingPoint(x: 0.5, y: 0.5)])
        #expect(addingPoint(DrawingPoint(x: 0.501, y: 0.5), to: stroke).points.count == 1)
        #expect(addingPoint(DrawingPoint(x: 0.51, y: 0.5), to: stroke).points.count == 2)
    }

    @Test func emptyOrHugeDrawingsAreRejected() {
        #expect(drawingValidationError(MessageDrawing()) != nil)
        #expect(drawingValidationError(squiggle) == nil)

        let tooManyPoints = MessageDrawing(strokes: [
            DrawingStroke(color: .ink, width: .thin, points: Array(repeating: DrawingPoint(x: 0.5, y: 0.5), count: maximumDrawingPoints + 1)),
        ])
        #expect(drawingValidationError(tooManyPoints) != nil)
    }

    @Test func drawingRoundTripsThroughThePayload() throws {
        let payload = try #require(encodeDrawing(squiggle))
        #expect(payload.count < maximumDrawingPayloadCharacters)
        #expect(decodeDrawing(payload) == squiggle)
        #expect(decodeDrawing("not json") == nil)
        #expect(decodeDrawing("{\"strokes\":[]}") == nil)
    }

    @Test func preparingContentPicksTheRightShape() throws {
        let text = try preparedMessage(from: .text("  hello  ", .yellow))
        #expect(text == PreparedMessage(text: "hello", color: .yellow, contentType: .text, drawingPayload: nil))

        let drawing = try preparedMessage(from: .drawing(squiggle))
        #expect(drawing.text == "")
        #expect(drawing.color == .mint)
        #expect(drawing.contentType == .drawing)
        #expect(drawing.retryKey == drawing.drawingPayload)

        #expect(throws: UserFacingError.self) { try preparedMessage(from: .drawing(MessageDrawing())) }
        #expect(throws: UserFacingError.self) { try preparedMessage(from: .text("   ", .ink)) }
    }

    @Test func drawingMessagesMapFromFirestoreFields() throws {
        let payload = try #require(encodeDrawing(squiggle))
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        let fields: [String: Any] = ["authorID": "a1", "text": "", "createdAt": created, "contentType": "drawing", "drawing": payload]
        let message = try #require(wallMessage(id: "m1", wallID: "w1", fields: fields))
        #expect(message.contentType == .drawing)
        #expect(message.drawing == squiggle)
        #expect(messageAccessibilityLabel(message, isMine: true).hasPrefix("You drew a picture."))

        var broken = fields
        broken["drawing"] = "garbage"
        #expect(wallMessage(id: "m1", wallID: "w1", fields: broken) == nil)
    }

    @Test func drawingFieldsIncludeThePayload() {
        let message = NewWallMessage(id: "m1", wallID: "w1", authorID: "a1", authorName: "Mira", text: "", color: .mint,
                                     normalizedX: 0.5, normalizedY: 0.5, contentType: .drawing, drawingPayload: "{}")
        let fields = firestoreFields(for: message)
        #expect(fields["contentType"] as? String == "drawing")
        #expect(fields["drawing"] as? String == "{}")
    }
}
