import Foundation

struct AppServices {
    let persistence: PersistenceController
    let localStore: LocalStore
    let auth = AuthService()
    let profiles = ProfileService()
    let walls = WallService()
    let messages = WallMessageService()
    let publisher = WallPublishService()
    let economy = EconomyService()
    let deletion = AccountDeletionService()
    let biometric = BiometricService()
    let location = LocationService()

    init() {
        persistence = PersistenceController()
        localStore = LocalStore(persistence: persistence)
    }
}
