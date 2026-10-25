import Foundation
import CoreLocation
import Observation

@MainActor @Observable
final class WallDetailViewModel {
    private(set) var proximity: WallProximity = .findingLocation
    private(set) var teaser: WallTeaser?
    private(set) var isLoadingTeaser = false
    private(set) var messages: [WallMessage] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var hasLoaded = false
    private(set) var isShowingSavedMessages = false
    private(set) var showingSavedMessagesSince: Date?

    let locationService: LocationService
    private let wall: Wall
    private let messageService: WallMessageService
    private let localStore: LocalStore
    private let accountID: String
    private var nextCursor: MessageCursor?
    private var latestLoadID = 0
    private var pendingPost: PendingPost?

    init(wall: Wall, messageService: WallMessageService, locationService: LocationService, localStore: LocalStore, accountID: String) {
        self.wall = wall
        self.messageService = messageService
        self.locationService = locationService
        self.localStore = localStore
        self.accountID = accountID
    }

    func savedDraft() -> MessageDraft? {
        localStore.draft(accountID: accountID, wallID: wall.id)
    }

    func saveDraft(text: String, color: MessageColor) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            discardDraft()
            return
        }
        try? localStore.saveDraft(MessageDraft(accountID: accountID, wallID: wall.id, text: text, color: color, updatedAt: Date()))
    }

    func discardDraft() {
        try? localStore.deleteDraft(accountID: accountID, wallID: wall.id)
    }

    var isUnlocked: Bool { proximity == .unlocked }

    var canLoadMore: Bool {
        nextCursor != nil && !isLoading && !isLoadingMore
    }

    func appeared() {
        locationService.startUpdating()
    }

    func disappeared() {
        locationService.stopUpdating()
    }

    func refreshProximity(now: Date) async {
        guard !isUnlocked else { return }

        proximity = wallProximity(wallCoordinate: wall.coordinate, access: locationService.access, fix: currentFix(), policy: wallReadingPolicy, now: now)

        if isUnlocked {
            if !hasLoaded {
                await loadFirstPage()
            }
        } else if teaser == nil && !isLoadingTeaser {
            await loadTeaser()
        }
    }

    func refresh() async {
        if isUnlocked {
            await loadFirstPage()
        } else {
            await loadTeaser()
        }
    }

    func post(_ content: MessageContent, author: UserProfile) async throws {
        let prepared = try preparedMessage(from: content)

        let freshFix = await locationService.freshLocation(timeoutSeconds: freshFixTimeoutSeconds).map(locationFix(from:))
        let postingCheck = wallProximity(wallCoordinate: wall.coordinate, access: locationService.access, fix: freshFix ?? currentFix(), policy: wallPostingPolicy, now: Date())
        if let blockedMessage = postingBlockedMessage(for: postingCheck, policy: wallPostingPolicy) {
            throw UserFacingError(message: blockedMessage)
        }

        let messageID = messageIDForPost(text: prepared.retryKey, color: prepared.color, previous: pendingPost) { UUID().uuidString }
        pendingPost = PendingPost(id: messageID, text: prepared.retryKey, color: prepared.color)
        let placement = messagePlacement(forMessageID: messageID)
        let newMessage = NewWallMessage(
            id: messageID,
            wallID: wall.id,
            authorID: author.id,
            authorName: author.displayName,
            text: prepared.text,
            color: prepared.color,
            normalizedX: placement.x,
            normalizedY: placement.y,
            contentType: prepared.contentType,
            drawingPayload: prepared.drawingPayload
        )

        do {
            let saved = try await messageService.post(newMessage)
            pendingPost = nil
            if prepared.contentType == .text {
                discardDraft()
            }
            messages = [saved] + messages.filter { $0.id != saved.id }
            hasLoaded = true
        } catch {
            throw UserFacingError(message: "Your message wasn't posted. Check your connection and try again.")
        }
    }

    func requestFreshFix() async {
        _ = await locationService.freshLocation(timeoutSeconds: freshFixTimeoutSeconds)
    }

    private func currentFix() -> LocationFix? {
        locationService.latestLocation.map(locationFix(from:))
    }

    func loadTeaser() async {
        isLoadingTeaser = true
        errorMessage = nil
        do {
            teaser = try await messageService.fetchTeaser(wallID: wall.id)
        } catch {
            errorMessage = "We couldn't load this wall. Check your connection and try again."
        }
        isLoadingTeaser = false
    }

    func loadFirstPage() async {
        latestLoadID += 1
        let loadID = latestLoadID
        isLoading = true
        errorMessage = nil

        do {
            let page = try await messageService.fetchMessages(wallID: wall.id, after: nil)
            guard loadID == latestLoadID else { return }
            messages = page.messages
            nextCursor = page.nextCursor
            hasLoaded = true
            isShowingSavedMessages = false
            showingSavedMessagesSince = nil
            try? localStore.replaceCachedMessages(page.messages, wallID: wall.id, accountID: accountID, fetchedAt: Date())
        } catch {
            guard loadID == latestLoadID else { return }
            let saved = localStore.cachedMessages(wallID: wall.id, accountID: accountID)
            if saved.messages.isEmpty {
                errorMessage = "We couldn't load messages. Check your connection and try again."
            } else {
                messages = saved.messages
                nextCursor = nil
                hasLoaded = true
                isShowingSavedMessages = true
                showingSavedMessagesSince = saved.savedAt
            }
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard let cursor = nextCursor, canLoadMore else { return }
        let loadID = latestLoadID
        isLoadingMore = true
        errorMessage = nil

        do {
            let page = try await messageService.fetchMessages(wallID: wall.id, after: cursor)
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

let freshFixTimeoutSeconds = 10.0

func locationFix(from location: CLLocation) -> LocationFix {
    LocationFix(coordinate: Coordinate(location.coordinate), horizontalAccuracyMeters: location.horizontalAccuracy, timestamp: location.timestamp)
}

func appendingNewMessages(_ newMessages: [WallMessage], to existing: [WallMessage]) -> [WallMessage] {
    let existingIDs = Set(existing.map(\.id))
    return existing + newMessages.filter { !existingIDs.contains($0.id) }
}
