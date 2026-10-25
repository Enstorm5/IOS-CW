import Foundation

struct LocationFix: Equatable {
    var coordinate: Coordinate
    var horizontalAccuracyMeters: Double
    var timestamp: Date
}

struct ProximityPolicy {
    var radiusMeters: Double
    var maximumAccuracyMeters: Double
    var maximumAgeSeconds: TimeInterval
}

let wallReadingPolicy = ProximityPolicy(radiusMeters: 50, maximumAccuracyMeters: 25, maximumAgeSeconds: 120)
let wallPostingPolicy = ProximityPolicy(radiusMeters: 50, maximumAccuracyMeters: 25, maximumAgeSeconds: 15)

enum WallProximity: Equatable {
    case unlocked
    case locationOff
    case approximateLocation
    case findingLocation
    case tooFar(distanceMeters: Double)
}

func wallProximity(wallCoordinate: Coordinate, access: LocationAccess, fix: LocationFix?, policy: ProximityPolicy, now: Date) -> WallProximity {
    switch access {
    case .notAsked, .denied, .restricted:
        return .locationOff
    case .allowed(let isPrecise):
        if !isPrecise { return .approximateLocation }
    }

    guard let fix,
          fix.horizontalAccuracyMeters >= 0,
          fix.horizontalAccuracyMeters <= policy.maximumAccuracyMeters,
          now.timeIntervalSince(fix.timestamp) <= policy.maximumAgeSeconds else {
        return .findingLocation
    }

    let distance = distanceInMeters(from: fix.coordinate, to: wallCoordinate)
    return distance <= policy.radiusMeters ? .unlocked : .tooFar(distanceMeters: distance)
}

func lockedWallMessage(for proximity: WallProximity, policy: ProximityPolicy) -> String? {
    let radius = "\(Int(policy.radiusMeters)) m"
    switch proximity {
    case .unlocked:
        return nil
    case .locationOff:
        return "Turn on location to read this wall. Walls unlock when you're within \(radius)."
    case .approximateLocation:
        return "Turn on Precise Location for Aura. Walls unlock when you're within \(radius)."
    case .findingLocation:
        return "Finding your location…"
    case .tooFar(let distanceMeters):
        return "Walk within \(radius) to read this wall. You're \(formattedDistance(meters: distanceMeters)) away."
    }
}

func postingBlockedMessage(for proximity: WallProximity, policy: ProximityPolicy) -> String? {
    switch proximity {
    case .unlocked:
        return nil
    case .locationOff, .approximateLocation:
        return "Turn on precise location to post on this wall."
    case .findingLocation:
        return "Waiting for a fresh location fix. Try again in a moment."
    case .tooFar(let distanceMeters):
        return "Move within \(Int(policy.radiusMeters)) m of the wall to post. You're \(formattedDistance(meters: distanceMeters)) away."
    }
}

func messageCountText(_ count: Int) -> String {
    switch count {
    case ...0: "No messages yet"
    case 1: "1 message"
    default: "\(count) messages"
    }
}
