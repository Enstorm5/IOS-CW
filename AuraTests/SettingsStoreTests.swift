import Testing
import Foundation
@testable import Aura

@MainActor
struct SettingsStoreTests {
    let store = LocalStore(persistence: PersistenceController(inMemory: true))

    @Test func defaultsToSystemTheme() {
        #expect(store.settings(accountID: "A") == UserSettings(theme: .system))
    }

    @Test func themeIsSavedUpdatedAndSeparatedPerAccount() throws {
        try store.saveSettings(UserSettings(theme: .dark), accountID: "A")
        try store.saveSettings(UserSettings(theme: .light), accountID: "B")
        #expect(store.settings(accountID: "A").theme == .dark)
        #expect(store.settings(accountID: "B").theme == .light)

        try store.saveSettings(UserSettings(theme: .system), accountID: "A")
        #expect(store.settings(accountID: "A").theme == .system)
    }

    @Test func appLockIsOffByDefaultAndSavedPerAccount() throws {
        #expect(store.settings(accountID: "A").appLockEnabled == false)
        try store.saveSettings(UserSettings(theme: .dark, appLockEnabled: true), accountID: "A")
        #expect(store.settings(accountID: "A") == UserSettings(theme: .dark, appLockEnabled: true))
        #expect(store.settings(accountID: "B").appLockEnabled == false)

        try store.deleteAccountData(accountID: "A")
        #expect(store.settings(accountID: "A").appLockEnabled == false)
    }

    @Test func questRemindersAreOffByDefaultAndSavedPerAccount() throws {
        #expect(store.settings(accountID: "A").questRemindersEnabled == false)
        try store.saveSettings(UserSettings(questRemindersEnabled: true), accountID: "A")
        #expect(store.settings(accountID: "A").questRemindersEnabled)
        #expect(store.settings(accountID: "B").questRemindersEnabled == false)
        try store.deleteAccountData(accountID: "A")
        #expect(store.settings(accountID: "A").questRemindersEnabled == false)
    }

    @Test func signOutClearsOnlyThatAccountsSettings() throws {
        try store.saveSettings(UserSettings(theme: .dark), accountID: "A")
        try store.saveSettings(UserSettings(theme: .dark), accountID: "B")

        try store.deleteAccountData(accountID: "A")
        #expect(store.settings(accountID: "A").theme == .system)
        #expect(store.settings(accountID: "B").theme == .dark)
    }

    @Test func drawingMessagesSurviveTheCache() throws {
        let drawing = MessageDrawing(strokes: [DrawingStroke(color: .mint, width: .thick, points: [DrawingPoint(x: 0.1, y: 0.2), DrawingPoint(x: 0.4, y: 0.5)])])
        let message = WallMessage(id: "d1", wallID: "w1", authorID: "a", authorName: "Mira", text: "", color: .mint, sparkCount: 0,
                                  createdAt: Date(timeIntervalSince1970: 1_800_000_000), contentType: .drawing, drawing: drawing)
        try store.replaceCachedMessages([message], wallID: "w1", accountID: "A", fetchedAt: Date(timeIntervalSince1970: 1_800_000_100))
        #expect(store.cachedMessages(wallID: "w1", accountID: "A").messages == [message])
    }

    @Test func keysCombineAccountAndItem() {
        #expect(localKey(accountID: "A", itemID: "w1") == "A|w1")
        #expect(localKey(accountID: "A", itemID: "w1") != localKey(accountID: "B", itemID: "w1"))
    }
}
