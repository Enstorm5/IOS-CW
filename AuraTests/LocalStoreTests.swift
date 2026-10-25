import Testing
import Foundation
@testable import Aura

@MainActor
struct LocalStoreTests {
    let store = LocalStore(persistence: PersistenceController(inMemory: true))
    let savedAt = Date(timeIntervalSince1970: 1_800_000_000)

    func draft(account: String, wall: String, text: String) -> MessageDraft {
        MessageDraft(accountID: account, wallID: wall, text: text, color: .mint, updatedAt: savedAt)
    }

    func message(_ id: String, minutesAgo: Double) -> WallMessage {
        WallMessage(id: id, wallID: "w1", authorID: "a1", authorName: "Mira", text: "hi \(id)", color: .ink, sparkCount: 2,
                    createdAt: savedAt.addingTimeInterval(-minutesAgo * 60), normalizedX: 0.2, normalizedY: 0.7)
    }

    @Test func draftSavesUpdatesAndDeletes() throws {
        try store.saveDraft(draft(account: "A", wall: "w1", text: "first"))
        try store.saveDraft(draft(account: "A", wall: "w1", text: "second"))
        #expect(store.draft(accountID: "A", wallID: "w1")?.text == "second")
        #expect(store.draftCount(accountID: "A") == 1)

        try store.deleteDraft(accountID: "A", wallID: "w1")
        #expect(store.draft(accountID: "A", wallID: "w1") == nil)
    }

    @Test func accountsNeverSeeEachOthersDrafts() throws {
        try store.saveDraft(draft(account: "A", wall: "w1", text: "mine"))
        #expect(store.draft(accountID: "B", wallID: "w1") == nil)
        #expect(store.draftCount(accountID: "B") == 0)
    }

    @Test func wallCacheUpsertsWithoutDuplicates() throws {
        let map = WallMapInfo(chunkCount: 2, version: 1, checksum: String(repeating: "a", count: 64), byteCount: 1_500_000, anchorName: "w1", size: WallSize(width: 1.2, height: 0.8))
        let first = Wall(id: "w1", title: "Old title", coordinate: Coordinate(latitude: 6.9, longitude: 79.8), kind: .community, map: map)
        let renamed = Wall(id: "w1", title: "New title", coordinate: first.coordinate, kind: .community, map: map)

        try store.cacheWalls([first], accountID: "A", fetchedAt: savedAt)
        try store.cacheWalls([renamed], accountID: "A", fetchedAt: savedAt.addingTimeInterval(60))

        let cached = store.cachedWalls(accountID: "A")
        #expect(cached.walls == [renamed])
        #expect(cached.savedAt == savedAt.addingTimeInterval(60))
        #expect(store.cachedWalls(accountID: "B").walls.isEmpty)
    }

    @Test func messageCacheReplacesTheWallsMessagesNewestFirst() throws {
        try store.replaceCachedMessages([message("old", minutesAgo: 30)], wallID: "w1", accountID: "A", fetchedAt: savedAt)
        try store.replaceCachedMessages([message("m1", minutesAgo: 10), message("m2", minutesAgo: 1)], wallID: "w1", accountID: "A", fetchedAt: savedAt)

        let cached = store.cachedMessages(wallID: "w1", accountID: "A")
        #expect(cached.messages.map(\.id) == ["m2", "m1"])
        #expect(cached.messages.first == message("m2", minutesAgo: 1))
    }

    @Test func signOutClearsOnlyThatAccount() throws {
        try store.saveDraft(draft(account: "A", wall: "w1", text: "a"))
        try store.saveDraft(draft(account: "B", wall: "w1", text: "b"))
        try store.replaceCachedMessages([message("m1", minutesAgo: 1)], wallID: "w1", accountID: "A", fetchedAt: savedAt)

        try store.deleteAccountData(accountID: "A")
        #expect(store.draftCount(accountID: "A") == 0)
        #expect(store.cachedMessages(wallID: "w1", accountID: "A").messages.isEmpty)
        #expect(store.draft(accountID: "B", wallID: "w1")?.text == "b")
    }

    @Test func resetDeletesEverything() throws {
        try store.saveDraft(draft(account: "A", wall: "w1", text: "a"))
        try store.deleteEverything()
        #expect(store.draftCount(accountID: "A") == 0)
    }

    @Test func messagesForOfflineAndSignOut() {
        #expect(offlineSavedText(nil, now: savedAt) == "You're offline.")
        #expect(signOutMessage(unsentDraftCount: 2) == "You have 2 unsent drafts on this phone. Signing out deletes them.")
    }
}
