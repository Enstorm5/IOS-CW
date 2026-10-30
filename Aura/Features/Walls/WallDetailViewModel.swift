import Foundation
import CoreLocation
import Observation

@MainActor @Observable
final class WallDetailViewModel {
    private(set) var proximity: WallProximity = .findingLocation
    private(set) var teaser: WallTeaser?
    private(set) var isLoadingTeaser = false
    private(set) var messages: [WallMessage] = []
    private(set) var justPostedMessage: WallMessage?
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
    private let statsStore: StatsStore
    private var isDiscoveryHandled = false
    private var isClaimingDiscovery = false
    private(set) var discoveryBanner: String?
    private(set) var sparkedMessageIDs: Set<String> = []
    private(set) var sparkingMessageIDs: Set<String> = []
    private(set) var actionError: String?

    init(wall: Wall, messageService: WallMessageService, locationService: LocationService, localStore: LocalStore, accountID: String, statsStore: StatsStore) {
        self.statsStore = statsStore
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

    // 50 m check
    func refreshProximity(now: Date) async {
        if !isUnlocked {
            proximity = wallProximity(wallCoordinate: wall.coordinate, access: locationService.access, fix: currentFix(), policy: wallReadingPolicy, now: now)

            if isUnlocked {
                if !hasLoaded {
                    await loadFirstPage()
                }
            } else if teaser == nil && !isLoadingTeaser {
                await loadTeaser()
            }
        }

        if isUnlocked {
            await claimDiscoveryIfEligible(now: now)
        }
    }

    // Discovery reward
    private func claimDiscoveryIfEligible(now: Date) async {
        guard !isDiscoveryHandled, !isClaimingDiscovery else { return }
        let rewardCheck = wallProximity(wallCoordinate: wall.coordinate, access: locationService.access, fix: currentFix(), policy: wallPostingPolicy, now: now)
        guard rewardCheck == .unlocked else { return }

        isClaimingDiscovery = true
        let result = await statsStore.claimDiscovery(wallID: wall.id)
        isClaimingDiscovery = false

        switch result {
        case .awarded:
            isDiscoveryHandled = true
            discoveryBanner = "+\(discoveryRewardPoints) points · New wall discovered"
        case .alreadyDiscovered:
            isDiscoveryHandled = true
        case .failed:
            break
        }
    }

    func refresh() async {
        if isUnlocked {
            await loadFirstPage()
        } else {
            await loadTeaser()
        }
    }

    // Post message
    // Message to place
    func takeJustPosted() -> WallMessage? {
        defer { justPostedMessage = nil }
        return justPostedMessage
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
            justPostedMessage = saved
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

    func loadMySparks() async {
        if let sparked = try? await messageService.mySparkedMessageIDs(userID: accountID, wallID: wall.id) {
            sparkedMessageIDs = sparked
        }
    }

    func toggleSpark(_ message: WallMessage) async {
        guard canSpark(message, userID: accountID), !sparkingMessageIDs.contains(message.id) else { return }
        let isAddingSpark = !sparkedMessageIDs.contains(message.id)
        sparkingMessageIDs.insert(message.id)
        actionError = nil

        do {
            let newCount = try await messageService.setSpark(userID: accountID, wallID: wall.id, messageID: message.id, isAddingSpark: isAddingSpark)
            if isAddingSpark {
                sparkedMessageIDs.insert(message.id)
            } else {
                sparkedMessageIDs.remove(message.id)
            }
            updateMessage(id: message.id) { $0.sparkCount = newCount }
        } catch {
            actionError = "Couldn't update the spark. Check your connection and try again."
        }
        sparkingMessageIDs.remove(message.id)
    }

    func edit(_ message: WallMessage, newText: String) async throws {
        guard canEdit(message, userID: accountID) else { return }
        let cleaned = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validationError = messageValidationError(cleaned) {
            throw UserFacingError(message: validationError)
        }
        do {
            try await messageService.editMessage(wallID: wall.id, messageID: message.id, text: cleaned)
        } catch {
            throw UserFacingError(message: "Couldn't save your edit. Check your connection and try again.")
        }
        updateMessage(id: message.id) { $0.text = cleaned }
    }

    func move(_ message: WallMessage, to placement: (x: Double, y: Double)) async throws {
        guard canMove(message, userID: accountID) else { return }
        do {
            try await messageService.moveMessage(wallID: wall.id, messageID: message.id, x: placement.x, y: placement.y)
        } catch {
            throw UserFacingError(message: "Couldn't move your message. Check your connection and try again.")
        }
        updateMessage(id: message.id) {
            $0.normalizedX = placement.x
            $0.normalizedY = placement.y
        }
    }

    func delete(_ message: WallMessage) async {
        guard canDelete(message, userID: accountID) else { return }
        actionError = nil
        do {
            try await messageService.deleteMessage(wallID: wall.id, messageID: message.id)
            messages.removeAll { $0.id == message.id }
            try? localStore.replaceCachedMessages(messages, wallID: wall.id, accountID: accountID, fetchedAt: Date())
        } catch {
            actionError = "Couldn't delete the message. Check your connection and try again."
        }
    }

    private func updateMessage(id: String, change: (inout WallMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
        try? localStore.replaceCachedMessages(messages, wallID: wall.id, accountID: accountID, fetchedAt: Date())
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
            await loadMySparks()
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

    // Load more
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

// Skip duplicates
func appendingNewMessages(_ newMessages: [WallMessage], to existing: [WallMessage]) -> [WallMessage] {
    let existingIDs = Set(existing.map(\.id))
    return existing + newMessages.filter { !existingIDs.contains($0.id) }
}
