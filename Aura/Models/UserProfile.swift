import Foundation

// Profile data
struct UserProfile: Equatable {
    var id: String
    var displayName: String
    var bio: String
    var avatarPreset: AvatarPreset
    var interests: [Interest]
}

enum Interest: String, CaseIterable, Identifiable {
    case cafes
    case campus
    case streetArt
    case liveMusic
    case parks
    case nightlife
    case bookshops
    case foodTrucks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cafes: "Cafes"
        case .campus: "Campus"
        case .streetArt: "Street art"
        case .liveMusic: "Live music"
        case .parks: "Parks"
        case .nightlife: "Nightlife"
        case .bookshops: "Bookshops"
        case .foodTrucks: "Food trucks"
        }
    }
}

enum AvatarPreset: String, CaseIterable, Identifiable {
    case magenta
    case mint
    case sunny
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .magenta: "Magenta"
        case .mint: "Mint"
        case .sunny: "Sunny"
        case .night: "Night"
        }
    }
}
