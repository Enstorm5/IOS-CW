import SwiftUI

struct RootView: View {
    let session: SessionStore

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                SplashView()
            case .signedOut:
                AuthFlowView(session: session)
            case .needsOnboarding(let userID, let suggestedName):
                InterestsView(session: session, userID: userID, suggestedName: suggestedName)
            case .signedIn(let profile):
                SignedInPlaceholderView(session: session, profile: profile)
            case .failed(let message):
                SessionErrorView(session: session, message: message)
            }
        }
        .animation(.default, value: session.state)
        .task { session.start() }
    }
}

struct SessionErrorView: View {
    let session: SessionStore
    let message: String
    @State private var signOutError: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
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
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.auraBackground)
    }
}
