import Foundation
import CoreLocation
import Observation

nonisolated enum LocationAccess: Equatable {
    case notAsked
    case denied
    case restricted
    case allowed(isPrecise: Bool)

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    var isBlocked: Bool {
        self == .denied || self == .restricted
    }
}

nonisolated func locationAccess(status: CLAuthorizationStatus, isPrecise: Bool) -> LocationAccess {
    switch status {
    case .notDetermined: .notAsked
    case .restricted: .restricted
    case .denied: .denied
    case .authorizedWhenInUse, .authorizedAlways: .allowed(isPrecise: isPrecise)
    @unknown default: .denied
    }
}

@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var access: LocationAccess = .notAsked
    private(set) var latestLocation: CLLocation?

    private let manager = CLLocationManager()
    private var activeUpdateRequests = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func requestAccessIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func startUpdating() {
        activeUpdateRequests += 1
        if activeUpdateRequests == 1 {
            manager.startUpdatingLocation()
        }
    }

    func stopUpdating() {
        activeUpdateRequests = max(0, activeUpdateRequests - 1)
        if activeUpdateRequests == 0 {
            manager.stopUpdatingLocation()
        }
    }

    func freshLocation(timeoutSeconds: Double) async -> CLLocation? {
        guard access.isAllowed else { return nil }
        let location = await firstLiveLocation(timeoutSeconds: timeoutSeconds)
        if let location {
            latestLocation = location
        }
        return location
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newAccess = locationAccess(status: manager.authorizationStatus, isPrecise: manager.accuracyAuthorization == .fullAccuracy)
        Task { @MainActor in
            self.access = newAccess
            if !newAccess.isAllowed {
                self.latestLocation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.latestLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

nonisolated func firstLiveLocation(timeoutSeconds: Double) async -> CLLocation? {
    await withTaskGroup(of: CLLocation?.self) { group in
        group.addTask {
            await firstLocationFromLiveUpdates()
        }
        group.addTask {
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}

nonisolated func firstLocationFromLiveUpdates() async -> CLLocation? {
    do {
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location {
                return location
            }
        }
    } catch {
        return nil
    }
    return nil
}
