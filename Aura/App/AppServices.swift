import Foundation

struct AppServices {
    let auth = AuthService()
    let profiles = ProfileService()
    let walls = WallService()
    let location = LocationService()
}
