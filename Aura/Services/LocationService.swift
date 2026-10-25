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

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25
    }

    func requestAccessIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
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
