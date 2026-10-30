import Testing
import Foundation
@testable import Aura

@MainActor
struct DrawingExtraTests {
    @Test func pointsAreCountedAcrossStrokes() {
        let drawing = MessageDrawing(strokes: [
            DrawingStroke(color: .ink, width: .thin, points: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 1)]),
            DrawingStroke(color: .mint, width: .thin, points: [DrawingPoint(x: 0.5, y: 0.5)]),
        ])
        #expect(drawingPointCount(drawing) == 3)
        #expect(drawingPointCount(MessageDrawing()) == 0)
    }

    @Test func cardColorFollowsTheFirstStrokeAndDefaultsToInk() {
        let drawing = MessageDrawing(strokes: [DrawingStroke(color: .yellow, width: .thin, points: [DrawingPoint(x: 0, y: 0)])])
        #expect(drawingCardColor(for: drawing) == .yellow)
        #expect(drawingCardColor(for: MessageDrawing()) == .ink)
    }

    @Test func tooManyStrokesAreRejected() {
        let stroke = DrawingStroke(color: .ink, width: .thin, points: [DrawingPoint(x: 0.1, y: 0.1)])
        let tooMany = MessageDrawing(strokes: Array(repeating: stroke, count: maximumDrawingStrokes + 1))
        #expect(drawingValidationError(tooMany) != nil)
        #expect(drawingValidationError(MessageDrawing(strokes: Array(repeating: stroke, count: maximumDrawingStrokes))) == nil)
    }

    @Test func decodingClampsPointsAndRejectsBrokenPayloads() throws {
        let payload = #"{"strokes":[{"color":"mint","width":"thin","points":[{"x":2.5,"y":-1}]}]}"#
        let drawing = try #require(decodeDrawing(payload))
        #expect(drawing.strokes[0].points == [DrawingPoint(x: 1, y: 0)])
        #expect(decodeDrawing(#"{"strokes":[{"color":"purple","width":"thin","points":[{"x":0,"y":0}]}]}"#) == nil)
        #expect(decodeDrawing(String(repeating: "x", count: maximumDrawingPayloadCharacters + 1)) == nil)
    }

    @Test func oversizedPayloadsAreNotEncoded() {
        let points = (0..<maximumDrawingPoints).map { DrawingPoint(x: Double($0 % 1000) / 1000, y: Double($0 / 2) / 1000) }
        let drawing = MessageDrawing(strokes: [DrawingStroke(color: .ink, width: .thick, points: points)])
        if let payload = encodeDrawing(drawing) {
            #expect(payload.count <= maximumDrawingPayloadCharacters)
        }
    }

    @Test func widthsGrow() {
        let fractions = StrokeWidth.allCases.map(\.fractionOfWidth)
        #expect(fractions == fractions.sorted())
    }

    @Test func textMessagesLabelsAreReadable() {
        let message = WallMessage(id: "m", wallID: "w", authorID: "a", authorName: "Mira", text: "hello", color: .mint, sparkCount: 2, createdAt: Date(timeIntervalSince1970: 0))
        #expect(messageAccessibilityLabel(message, isMine: false) == "Mira wrote hello. 2 sparks.")
        #expect(messageAccessibilityLabel(message, isMine: true) == "You wrote hello. 2 sparks.")
    }

    @Test func aDrawingBecomesAnOpaqueImageOfTheRequestedSize() throws {
        let drawing = MessageDrawing(strokes: [
            DrawingStroke(color: .magenta, width: .thick, points: [DrawingPoint(x: 0.1, y: 0.1), DrawingPoint(x: 0.9, y: 0.8)]),
            DrawingStroke(color: .mint, width: .medium, brush: .neon, points: [DrawingPoint(x: 0.2, y: 0.7), DrawingPoint(x: 0.8, y: 0.2)]),
        ])
        let image = try #require(drawingCGImage(drawing, pixelWidth: 320))
        #expect(image.width == 320)
        #expect(image.height == Int((320 / drawingAspectRatio).rounded()))
        #expect(drawingCGImage(MessageDrawing(), pixelWidth: 160) != nil)
    }
}

