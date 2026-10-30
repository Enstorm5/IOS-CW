import SwiftUI
import GoogleSignIn

// Screen by session
struct RootView: View {
    let session: SessionStore
    let services: AppServices

    @State private var requestedTab: AppTab?

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                SplashView()
            case .signedOut:
                AuthFlowView(session: session)
            case .needsOnboarding(let userID, let suggestedName):
                OnboardingFlowView(session: session, userID: userID, suggestedName: suggestedName, locationService: services.location)
            case .signedIn(let profile):
                MainTabView(session: session, profile: profile, services: services, requestedTab: $requestedTab)
            case .failed(let message):
                SessionErrorView(session: session, message: message)
            }
        }
        .animation(.default, value: session.state)
        .task {
            session.start()
            services.notifications.onOpenQuests = { requestedTab = .quests }
        }
        .onOpenURL { url in
            if GIDSignIn.sharedInstance.handle(url) { return }
            requestedTab = appTab(forDeepLink: url)
        }
        .onChange(of: session.state) {
            switch session.state {
            case .signedIn(let profile):
                services.widgetSnapshots.keepOnly(accountID: profile.id)
            case .signedOut, .needsOnboarding:
                services.widgetSnapshots.keepOnly(accountID: nil)
                services.notifications.cancelQuestReminders()
            case .loading, .failed:
                break
            }
        }
    }
}

// Profile load error
struct SessionErrorView: View {
    let session: SessionStore
    let message: String
    @State private var signOutError: String?

    var body: some View {
        VStack(spacing: AuraSpacing.large) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.auraIcon)
                .foregroundStyle(Color.auraMuted)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.auraText)
            if let signOutError {
                ErrorMessage(text: signOutError)
            }
            Spacer()
            Button("Try again") {
                Task { await session.reload() }
            }
            .buttonStyle(AuraButtonStyle())
            Button("Sign out") {
                do {
                    try session.signOut()
                } catch {
                    signOutError = error.localizedDescription
                }
            }
            .buttonStyle(AuraButtonStyle(kind: .outline))
        }
        .padding(AuraSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.auraBackground)
    }
}
