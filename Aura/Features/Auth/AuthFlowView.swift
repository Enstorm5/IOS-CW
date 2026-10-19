import SwiftUI

enum AuthRoute: Hashable {
    case signUp
    case logIn
    case resetPassword
}

struct AuthFlowView: View {
    let session: SessionStore
    @State private var path: [AuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onFinish: { path.append(.signUp) },
                onLogIn: { path.append(.logIn) }
            )
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .signUp:
                    SignUpView(session: session, onLogInInstead: { path = [.logIn] })
                case .logIn:
                    LogInView(
                        session: session,
                        onForgotPassword: { path.append(.resetPassword) },
                        onSignUpInstead: { path = [.signUp] }
                    )
                case .resetPassword:
                    ResetPasswordView(session: session)
                }
            }
        }
        .tint(Color.auraText)
    }
}
