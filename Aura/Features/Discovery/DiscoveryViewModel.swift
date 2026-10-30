import Foundation
import CoreLocation
import Observation

let discoveryRadiusMeters = 1000.0
let searchAgainDistanceMeters = 250.0
let discoveryFallbackCenter = Coordinate(latitude: 6.9110, longitude: 79.8640)

@MainActor @Observable
// Map search state
final class DiscoveryViewModel {
    private(set) var nearbyWalls: [NearbyWall] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastSearchCenter: Coordinate?
    private(set) var showingSavedWallsSince: Date?
    private(set) var isShowingSavedWalls = false
    var selectedWallID: String?
    var openedWall: Wall?
    private(set) var opensWithWriter = false

    let locationService: LocationService
    private let wallService: WallService
    private let localStore: LocalStore
    private let accountID: String
    private var lastRequestedCenter: Coordinate?
    private var latestSearchID = 0

    init(wallService: WallService, locationService: LocationService, localStore: LocalStore, accountID: String) {
        self.wallService = wallService
        self.locationService = locationService
        self.localStore = localStore
        self.accountID = accountID
    }

    var selectedWall: NearbyWall? {
        nearbyWalls.first { $0.id == selectedWallID }
    }

    var hasSearched: Bool { lastSearchCenter != nil }

    func mapAppeared() {
        locationService.requestAccessIfNeeded()
        locationService.startUpdating()
    }

    func mapDisappeared() {
        locationService.stopUpdating()
    }

    // Search on move
    func locationOrAccessChanged() async {
        if locationService.access.isAllowed, let location = locationService.latestLocation {
            let center = Coordinate(location.coordinate)
            if shouldSearchAgain(lastCenter: lastSearchCenter, newCenter: center, minimumMoveMeters: searchAgainDistanceMeters) {
                await search(around: center)
            }
        } else if locationService.access.isBlocked && lastSearchCenter == nil {
            await search(around: discoveryFallbackCenter)
        }
    }

    // Nearby wall search
    func search(around center: Coordinate) async {
        latestSearchID += 1
        let searchID = latestSearchID
        lastRequestedCenter = center
        isLoading = true
        errorMessage = nil

        do {
            let walls = try await wallService.fetchPublicWalls(near: center, radiusMeters: discoveryRadiusMeters)
            guard searchID == latestSearchID else { return }
            nearbyWalls = walls
            lastSearchCenter = center
            isShowingSavedWalls = false
            showingSavedWallsSince = nil
            try? localStore.cacheWalls(walls.map(\.wall), accountID: accountID, fetchedAt: Date())
            if selectedWall == nil {
                selectedWallID = nil
            }
        } catch {
            guard searchID == latestSearchID else { return }
            // Offline fallback
            let saved = localStore.cachedWalls(accountID: accountID)
            let savedNearby = wallsWithinRadius(from: saved.walls, center: center, radiusMeters: discoveryRadiusMeters)
            if savedNearby.isEmpty {
                errorMessage = "We couldn't load walls. Check your connection and try again."
            } else {
                nearbyWalls = savedNearby
                lastSearchCenter = center
                isShowingSavedWalls = true
                showingSavedWallsSince = saved.savedAt
            }
        }
        isLoading = false
    }

    func open(_ wall: Wall, startWriting: Bool = false) {
        opensWithWriter = startWriting
        openedWall = wall
    }

    func removeWall(id: String) {
        nearbyWalls.removeAll { $0.id == id }
        if selectedWallID == id {
            selectedWallID = nil
        }
        try? localStore.removeCachedWall(wallID: id, accountID: accountID)
    }

    func refreshIfSearched() async {
        guard hasSearched else { return }
        await retry()
    }

    func retry() async {
        await search(around: lastRequestedCenter ?? discoveryFallbackCenter)
    }

    func canSearchArea(at visibleCenter: Coordinate?) -> Bool {
        guard let visibleCenter, let lastSearchCenter, !isLoading else { return false }
        return distanceInMeters(from: lastSearchCenter, to: visibleCenter) > searchAgainDistanceMeters
    }

    func distanceText(to wall: Wall) -> String? {
        guard locationService.access.isAllowed, let location = locationService.latestLocation else { return nil }
        let meters = distanceInMeters(from: Coordinate(location.coordinate), to: wall.coordinate)
        return "\(formattedDistance(meters: meters)) away"
    }
}
