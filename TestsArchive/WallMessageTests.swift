import Testing
import Foundation
@testable import Aura

@MainActor
struct WallMessageTests {
    let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

    func message(_ id: String) -> WallMessage {
        WallMessage(id: id, wallID: "w1", authorID: "a1", authorName: "Mira", text: "hi", color: .mint, sparkCount: 1, createdAt: createdAt)
    }

    @Test func mappingReadsAllFields() {
        let fields: [String: Any] = [
            "authorID": "a1", "authorName": "Mira", "text": "hi",
            "color": "mint", "sparkCount": 1, "createdAt": createdAt,
        ]
        #expect(wallMessage(id: "m1", wallID: "w1", fields: fields) == message("m1"))
    }

    @Test func mappingNeedsAuthorTextAndDate() {
        #expect(wallMessage(id: "m1", wallID: "w1", fields: ["authorID": "a1", "text": "hi"]) == nil)
        #expect(wallMessage(id: "m1", wallID: "w1", fields: ["authorID": "a1", "createdAt": createdAt]) == nil)
    }

    @Test func mappingDefaultsUnknownValues() {
        let fields: [String: Any] = ["authorID": "a1", "text": "hi", "createdAt": createdAt, "color": "rainbow", "sparkCount": -4]
        let result = wallMessage(id: "m1", wallID: "w1", fields: fields)
        #expect(result?.color == .magenta)
        #expect(result?.sparkCount == 0)
        #expect(result?.authorName == "Explorer")
    }

    @Test func nextPageSkipsMessagesAlreadyShown() {
        let combined = appendingNewMessages([message("b"), message("c")], to: [message("a"), message("b")])
        #expect(combined.map(\.id) == ["a", "b", "c"])
    }
}
