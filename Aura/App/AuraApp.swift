import SwiftUI
import FirebaseCore

@main
struct AuraApp: App {
    private let services: AppServices
    @State private var session: SessionStore

    init() {
        FirebaseApp.configure()
        let services = AppServices()
        self.services = services
        _session = State(initialValue: SessionStore(authService: services.auth, profileService: services.profiles))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, services: services)
        }
    }
}
