import Testing
import CoreLocation
@testable import Aura

@MainActor
struct GeoTests {
    let colomboSeven = Coordinate(latitude: 6.9110, longitude: 79.8640)

    @Test func oneDegreeOfLatitudeIsAbout111Kilometres() {
        let distance = distanceInMeters(from: Coordinate(latitude: 0, longitude: 0), to: Coordinate(latitude: 1, longitude: 0))
        #expect(abs(distance - 111_195) < 10)
    }

    @Test func distanceToSamePointIsZero() {
        #expect(distanceInMeters(from: colomboSeven, to: colomboSeven) == 0)
    }

    @Test func distanceMatchesCoreLocation() {
        let library = Coordinate(latitude: 6.9113, longitude: 79.8597)
        let ours = distanceInMeters(from: colomboSeven, to: library)
        let apple = CLLocation(latitude: 6.9110, longitude: 79.8640).distance(from: CLLocation(latitude: 6.9113, longitude: 79.8597))
        #expect(abs(ours - apple) < 5)
    }

    @Test func geohashMatchesKnownValue() {
        #expect(geohash(for: Coordinate(latitude: 42.6, longitude: -5.6), precision: 5) == "ezs42")
        #expect(geohash(for: Coordinate(latitude: 57.64911, longitude: 10.40744), precision: 11) == "u4pruydqqvj")
    }

    @Test func queryRangesCoverEveryPointInsideTheRadius() {
        let radius = 1000.0
        let ranges = geohashQueryRanges(center: colomboSeven, radiusMeters: radius)
        let offsets = searchOffsetsDegrees(center: colomboSeven, radiusMeters: radius)

        for latitudeStep in stride(from: -1.0, through: 1.0, by: 0.05) {
            for longitudeStep in stride(from: -1.0, through: 1.0, by: 0.05) {
                let point = Coordinate(
                    latitude: colomboSeven.latitude + latitudeStep * offsets.latitude,
                    longitude: colomboSeven.longitude + longitudeStep * offsets.longitude
                )
                guard distanceInMeters(from: colomboSeven, to: point) <= radius else { continue }
                let hash = geohash(for: point, precision: 9)
                #expect(ranges.contains { hash >= $0.start && hash <= $0.end })
            }
        }
    }

    @Test func queryRangesAreFewAndUnique() {
        let ranges = geohashQueryRanges(center: colomboSeven, radiusMeters: 1000)
        #expect(!ranges.isEmpty && ranges.count <= 9)
        #expect(Set(ranges.map(\.start)).count == ranges.count)
    }

    @Test func nearbyWallsFiltersSortsAndRemovesDuplicates() {
        let close = Wall(id: "close", title: "Close", coordinate: Coordinate(latitude: 6.9112, longitude: 79.8640), kind: .community)
        let middle = Wall(id: "middle", title: "Middle", coordinate: Coordinate(latitude: 6.9150, longitude: 79.8640), kind: .sponsored)
        let far = Wall(id: "far", title: "Far", coordinate: Coordinate(latitude: 6.9300, longitude: 79.8640), kind: .community)

        let result = nearbyWalls(from: [middle, far, close, middle], center: colomboSeven, radiusMeters: 1000)
        #expect(result.map(\.id) == ["close", "middle"])
    }

    @Test func searchAgainOnlyAfterMovingFarEnough() {
        let nearby = Coordinate(latitude: 6.9120, longitude: 79.8640)
        let farther = Coordinate(latitude: 6.9140, longitude: 79.8640)
        #expect(shouldSearchAgain(lastCenter: nil, newCenter: colomboSeven, minimumMoveMeters: 250))
        #expect(!shouldSearchAgain(lastCenter: colomboSeven, newCenter: nearby, minimumMoveMeters: 250))
        #expect(shouldSearchAgain(lastCenter: colomboSeven, newCenter: farther, minimumMoveMeters: 250))
    }

    @Test(arguments: [(3.0, "10 m"), (124.0, "120 m"), (994.0, "990 m"), (996.0, "1.0 km"), (1260.0, "1.3 km")])
    func distanceLabels(meters: Double, expected: String) {
        #expect(formattedDistance(meters: meters) == expected)
    }

    @Test func locationAccessMapping() {
        #expect(locationAccess(status: .notDetermined, isPrecise: true) == .notAsked)
        #expect(locationAccess(status: .denied, isPrecise: true) == .denied)
        #expect(locationAccess(status: .restricted, isPrecise: true) == .restricted)
        #expect(locationAccess(status: .authorizedWhenInUse, isPrecise: false) == .allowed(isPrecise: false))
    }

    @Test func wallMappingNeedsTitleAndCoordinates() {
        let fields: [String: Any] = ["title": "Steps", "latitude": 6.9, "longitude": 79.8, "kind": "sponsored"]
        #expect(wall(id: "w1", fields: fields) == Wall(id: "w1", title: "Steps", coordinate: Coordinate(latitude: 6.9, longitude: 79.8), kind: .sponsored))
        #expect(wall(id: "w1", fields: ["title": "Steps"]) == nil)
        #expect(wall(id: "w1", fields: ["title": "Steps", "latitude": 6.9, "longitude": 79.8, "kind": "unknown"])?.kind == .community)
    }
}
