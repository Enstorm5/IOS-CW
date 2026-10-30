import Testing
import Foundation
import CoreGraphics
@testable import Aura

@MainActor
struct MessageActionsTests {
    func message(author: String, type: MessageContentType = .text) -> WallMessage {
        WallMessage(id: "m1", wallID: "w1", authorID: author, authorName: "Mira", text: "hi", color: .mint,
                    sparkCount: 3, createdAt: Date(timeIntervalSince1970: 0), contentType: type)
    }

    @Test func onlyOthersCanSpark() {
        #expect(canSpark(message(author: "a"), userID: "b"))
        #expect(!canSpark(message(author: "a"), userID: "a"))
    }

    @Test func authorsEditTextAndDeleteAnything() {
        #expect(canEdit(message(author: "a"), userID: "a"))
        #expect(!canEdit(message(author: "a", type: .drawing), userID: "a"))
        #expect(!canEdit(message(author: "a"), userID: "b"))
        #expect(canDelete(message(author: "a", type: .drawing), userID: "a"))
        #expect(!canDelete(message(author: "a"), userID: "b"))
    }

    @Test func sparkCountNeverGoesNegative() {
        #expect(sparkCountAfterToggle(3, isAddingSpark: true) == 4)
        #expect(sparkCountAfterToggle(3, isAddingSpark: false) == 2)
        #expect(sparkCountAfterToggle(0, isAddingSpark: false) == 0)
        #expect(sparkDocumentID(wallID: "w1", messageID: "m1") == "w1_m1")
    }

    @Test func onlyTheAuthorCanMoveAMessage() {
        let message = WallMessage(id: "m", wallID: "w", authorID: "a", authorName: "A", text: "hi", color: .mint, sparkCount: 0, createdAt: Date(timeIntervalSince1970: 0))
        #expect(canMove(message, userID: "a"))
        #expect(!canMove(message, userID: "b"))
    }

    @Test func draggingMovesByTheFractionOfTheCanvasAndStaysOnTheWall() {
        let canvas = CGSize(width: 400, height: 200)
        let moved = movedPlacement(start: (0.5, 0.5), translation: CGSize(width: 100, height: -50), canvas: canvas)
        #expect(moved.x == 0.75 && moved.y == 0.25)

        let far = movedPlacement(start: (0.5, 0.5), translation: CGSize(width: 4_000, height: -4_000), canvas: canvas)
        #expect(far.x == 0.95 && far.y == 0.05)

        let still = movedPlacement(start: (0.3, 0.6), translation: CGSize(width: 10, height: 10), canvas: .zero)
        #expect(still.x == 0.3 && still.y == 0.6)
    }

    @Test func placementsAreClampedAndRoundedForStorage() {
        #expect(clampedPlacement(-1) == 0.05)
        #expect(clampedPlacement(2) == 0.95)
        #expect(clampedPlacement(0.123456) == 0.123)
        #expect(messagePlacement(forMessageID: "any").x >= messageMoveMargin)
    }
}

