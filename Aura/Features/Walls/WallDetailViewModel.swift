import Foundation
import Observation

@MainActor @Observable
final class WallDetailViewModel {
    private(set) var messages: [WallMessage] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var hasLoaded = false

    private let wallID: String
    private let messageService: WallMessageService
    private var nextCursor: MessageCursor?
    private var latestLoadID = 0

    init(wallID: String, messageService: WallMessageService) {
        self.wallID = wallID
        self.messageService = messageService
    }

    var canLoadMore: Bool {
        nextCursor != nil && !isLoading && !isLoadingMore
    }

    func loadFirstPage() async {
        latestLoadID += 1
        let loadID = latestLoadID
        isLoading = true
        errorMessage = nil

        do {
            let page = try await messageService.fetchMessages(wallID: wallID, after: nil)
            guard loadID == latestLoadID else { return }
            messages = page.messages
            nextCursor = page.nextCursor
            hasLoaded = true
        } catch {
            guard loadID == latestLoadID else { return }
            errorMessage = "We couldn't load messages. Check your connection and try again."
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard let cursor = nextCursor, canLoadMore else { return }
        let loadID = latestLoadID
        isLoadingMore = true
        errorMessage = nil

        do {
            let page = try await messageService.fetchMessages(wallID: wallID, after: cursor)
            guard loadID == latestLoadID else { return }
            messages = appendingNewMessages(page.messages, to: messages)
            nextCursor = page.nextCursor
        } catch {
            guard loadID == latestLoadID else { return }
            errorMessage = "We couldn't load more messages. Try again."
        }
        isLoadingMore = false
    }
}

func appendingNewMessages(_ newMessages: [WallMessage], to existing: [WallMessage]) -> [WallMessage] {
    let existingIDs = Set(existing.map(\.id))
    return existing + newMessages.filter { !existingIDs.contains($0.id) }
}
