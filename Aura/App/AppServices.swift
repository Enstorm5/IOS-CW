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
    let crews = CrewService()
    let deletion: AccountDeletionService
    let biometric = BiometricService()
    let location = LocationService()
    let widgetSnapshots = WidgetSnapshotService()

    init() {
        persistence = PersistenceController()
        localStore = LocalStore(persistence: persistence)
        deletion = AccountDeletionService(crews: crews)
    }
}
