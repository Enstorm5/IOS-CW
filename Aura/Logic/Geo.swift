import Foundation

let earthRadiusMeters = 6_371_000.0
let metersPerDegreeLatitude = 2 * Double.pi * earthRadiusMeters / 360

func distanceInMeters(from start: Coordinate, to end: Coordinate) -> Double {
    let startLatitude = start.latitude * .pi / 180
    let endLatitude = end.latitude * .pi / 180
    let latitudeChange = (end.latitude - start.latitude) * .pi / 180
    let longitudeChange = (end.longitude - start.longitude) * .pi / 180

    let a = sin(latitudeChange / 2) * sin(latitudeChange / 2)
        + cos(startLatitude) * cos(endLatitude) * sin(longitudeChange / 2) * sin(longitudeChange / 2)
    return earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a))
}

private let geohashAlphabet = Array("0123456789bcdefghjkmnpqrstuvwxyz")

func geohash(for coordinate: Coordinate, precision: Int) -> String {
    var minLatitude = -90.0, maxLatitude = 90.0
    var minLongitude = -180.0, maxLongitude = 180.0
    var hash = ""
    var characterIndex = 0
    var bitCount = 0
    var isLongitudeBit = true

    while hash.count < precision {
        if isLongitudeBit {
            let middle = (minLongitude + maxLongitude) / 2
            if coordinate.longitude >= middle {
                characterIndex = characterIndex * 2 + 1
                minLongitude = middle
            } else {
                characterIndex = characterIndex * 2
                maxLongitude = middle
            }
        } else {
            let middle = (minLatitude + maxLatitude) / 2
            if coordinate.latitude >= middle {
                characterIndex = characterIndex * 2 + 1
                minLatitude = middle
            } else {
                characterIndex = characterIndex * 2
                maxLatitude = middle
            }
        }
        isLongitudeBit.toggle()
        bitCount += 1

        if bitCount == 5 {
            hash.append(geohashAlphabet[characterIndex])
            characterIndex = 0
            bitCount = 0
        }
    }
    return hash
}

func geohashCellSizeDegrees(precision: Int) -> (latitude: Double, longitude: Double) {
    let totalBits = precision * 5
    let longitudeBits = (totalBits + 1) / 2
    let latitudeBits = totalBits / 2
    return (180 / pow(2, Double(latitudeBits)), 360 / pow(2, Double(longitudeBits)))
}

struct GeohashRange: Equatable {
    let start: String
    let end: String
}

func searchOffsetsDegrees(center: Coordinate, radiusMeters: Double) -> (latitude: Double, longitude: Double) {
    let latitudeOffset = radiusMeters / metersPerDegreeLatitude
    let longitudeOffset = radiusMeters / (metersPerDegreeLatitude * cos(center.latitude * .pi / 180))
    return (latitudeOffset, longitudeOffset)
}

func geohashSearchPrecision(center: Coordinate, radiusMeters: Double) -> Int {
    let offsets = searchOffsetsDegrees(center: center, radiusMeters: radiusMeters)
    for precision in stride(from: 9, through: 1, by: -1) {
        let cell = geohashCellSizeDegrees(precision: precision)
        if cell.latitude >= offsets.latitude && cell.longitude >= offsets.longitude {
            return precision
        }
    }
    return 1
}

func geohashQueryRanges(center: Coordinate, radiusMeters: Double) -> [GeohashRange] {
    let precision = geohashSearchPrecision(center: center, radiusMeters: radiusMeters)
    let offsets = searchOffsetsDegrees(center: center, radiusMeters: radiusMeters)

    var hashes: [String] = []
    for latitudeStep in [-1.0, 0, 1] {
        for longitudeStep in [-1.0, 0, 1] {
            let point = Coordinate(
                latitude: min(90, max(-90, center.latitude + latitudeStep * offsets.latitude)),
                longitude: center.longitude + longitudeStep * offsets.longitude
            )
            let hash = geohash(for: point, precision: precision)
            if !hashes.contains(hash) {
                hashes.append(hash)
            }
        }
    }
    return hashes.sorted().map { GeohashRange(start: $0, end: $0 + "~") }
}

func nearbyWalls(from walls: [Wall], center: Coordinate, radiusMeters: Double) -> [NearbyWall] {
    var seenIDs: Set<String> = []
    var result: [NearbyWall] = []
    for wall in walls where !seenIDs.contains(wall.id) {
        seenIDs.insert(wall.id)
        let distance = distanceInMeters(from: center, to: wall.coordinate)
        if distance <= radiusMeters {
            result.append(NearbyWall(wall: wall, distanceMeters: distance))
        }
    }
    return result.sorted {
        $0.distanceMeters == $1.distanceMeters ? $0.id < $1.id : $0.distanceMeters < $1.distanceMeters
    }
}

func shouldSearchAgain(lastCenter: Coordinate?, newCenter: Coordinate, minimumMoveMeters: Double) -> Bool {
    guard let lastCenter else { return true }
    return distanceInMeters(from: lastCenter, to: newCenter) > minimumMoveMeters
}

func formattedDistance(meters: Double) -> String {
    let roundedMeters = max(10, Int((meters / 10).rounded()) * 10)
    if roundedMeters < 1000 {
        return "\(roundedMeters) m"
    }
    return String(format: "%.1f km", meters / 1000)
}
