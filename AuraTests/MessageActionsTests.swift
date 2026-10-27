import Testing
import Foundation
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
}
