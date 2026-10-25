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

    let locationService: LocationService
    private let wall: Wall
    private let messageService: WallMessageService
    private var nextCursor: MessageCursor?
    private var latestLoadID = 0
    private var pendingPost: PendingPost?

    init(wall: Wall, messageService: WallMessageService, locationService: LocationService) {
        self.wall = wall
        self.messageService = messageService
        self.locationService = locationService
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

    func post(text: String, color: MessageColor, author: UserProfile, now: Date) async throws {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validationError = messageValidationError(cleaned) {
            throw UserFacingError(message: validationError)
        }

        let postingCheck = wallProximity(wallCoordinate: wall.coordinate, access: locationService.access, fix: currentFix(), policy: wallPostingPolicy, now: now)
        if let blockedMessage = postingBlockedMessage(for: postingCheck, policy: wallPostingPolicy) {
            throw UserFacingError(message: blockedMessage)
        }

        let messageID = messageIDForPost(text: cleaned, color: color, previous: pendingPost) { UUID().uuidString }
        pendingPost = PendingPost(id: messageID, text: cleaned, color: color)
        let placement = messagePlacement(forMessageID: messageID)
        let newMessage = NewWallMessage(
            id: messageID,
            wallID: wall.id,
            authorID: author.id,
            authorName: author.displayName,
            text: cleaned,
            color: color,
            normalizedX: placement.x,
            normalizedY: placement.y
        )

        do {
            let saved = try await messageService.post(newMessage)
            pendingPost = nil
            messages = [saved] + messages.filter { $0.id != saved.id }
            hasLoaded = true
        } catch {
            throw UserFacingError(message: "Your message wasn't posted. Check your connection and try again.")
        }
    }

    private func currentFix() -> LocationFix? {
        locationService.latestLocation.map {
            LocationFix(coordinate: Coordinate($0.coordinate), horizontalAccuracyMeters: $0.horizontalAccuracy, timestamp: $0.timestamp)
        }
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

func appendingNewMessages(_ newMessages: [WallMessage], to existing: [WallMessage]) -> [WallMessage] {
    let existingIDs = Set(existing.map(\.id))
    return existing + newMessages.filter { !existingIDs.contains($0.id) }
}
