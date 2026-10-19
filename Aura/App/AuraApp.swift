import SwiftUI
import FirebaseCore

@main
struct AuraApp: App {
    @State private var session: SessionStore

    init() {
        FirebaseApp.configure()
        _session = State(initialValue: SessionStore(authService: AuthService(), profileService: ProfileService()))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
        }
    }
}
