import Foundation

struct AppServices {
    let persistence: PersistenceController
    let localStore: LocalStore
    let auth = AuthService()
    let profiles = ProfileService()
    let walls = WallService()
    let messages = WallMessageService()
    let publisher = WallPublishService()
    let location = LocationService()

    init() {
        persistence = PersistenceController()
        localStore = LocalStore(persistence: persistence)
    }
}
