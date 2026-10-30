import Foundation
import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

enum GoogleSignInSetupError: Error {
    case notConfigured
    case noScreen
    case noToken

    var message: String {
        switch self {
        case .notConfigured: "Google sign-in isn't set up for this build yet."
        case .noScreen: "Couldn't open Google sign-in. Try again."
        case .noToken: "Google didn't return a sign-in token. Try again."
        }
    }
}

final class AuthService {
    private let auth = Auth.auth()

    var currentUserID: String? { auth.currentUser?.uid }
    var currentDisplayName: String? { auth.currentUser?.displayName }
    var currentEmail: String? { auth.currentUser?.email }
    var signInMethod: SignInMethod { signInMethodFrom(providerIDs: auth.currentUser?.providerData.map(\.providerID) ?? []) }

    func observeSignIn(_ onChange: @escaping (String?) -> Void) -> AuthStateDidChangeListenerHandle {
        auth.addStateDidChangeListener { _, user in
            onChange(user?.uid)
        }
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = displayName
        try await change.commitChanges()
    }

    func logIn(email: String, password: String) async throws {
        _ = try await auth.signIn(withEmail: email, password: password)
    }

    // Google sign-in
    func logInWithGoogle() async throws {
        let credential = try await googleCredential()
        _ = try await auth.signIn(with: credential)
    }

    func reauthenticateWithGoogle() async throws {
        guard let user = auth.currentUser else {
            throw UserFacingError(message: "You're not signed in.")
        }
        let credential = try await googleCredential()
        _ = try await user.reauthenticate(with: credential)
    }

    private func googleCredential() async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else { throw GoogleSignInSetupError.notConfigured }
        guard let presenter = topViewController() else { throw GoogleSignInSetupError.noScreen }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else { throw GoogleSignInSetupError.noToken }
        return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
    }

    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try auth.signOut()
    }

    // Re-authenticate
    func reauthenticate(password: String) async throws {
        guard let user = auth.currentUser, let email = user.email else {
            throw UserFacingError(message: "You're not signed in.")
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await user.reauthenticate(with: credential)
    }

    func deleteCurrentUser() async throws {
        guard let user = auth.currentUser else { return }
        try await user.delete()
    }
}

// Readable auth errors
func authErrorMessage(for error: Error) -> String {
    let nsError = error as NSError
    guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
        return "Something went wrong. Please try again."
    }

    switch code {
    case .invalidEmail:
        return "That email doesn't look right."
    case .emailAlreadyInUse:
        return "An account already uses this email. Try logging in instead."
    case .weakPassword:
        return "That password is too weak. Try a longer one."
    case .wrongPassword, .invalidCredential, .userNotFound:
        return "Email or password is incorrect."
    case .userDisabled:
        return "This account has been disabled."
    case .networkError:
        return "You're offline. Check your connection and try again."
    case .tooManyRequests:
        return "Too many attempts. Wait a moment and try again."
    case .accountExistsWithDifferentCredential:
        return "An account already uses this email with a different sign-in method."
    case .operationNotAllowed:
        return "This sign-in method isn't turned on for this app yet."
    default:
        return "Something went wrong. Please try again."
    }
}

func googleSignInErrorMessage(for error: Error) -> String? {
    let nsError = error as NSError
    if isGoogleSignInCancelled(domain: nsError.domain, code: nsError.code) { return nil }
    if let setupError = error as? GoogleSignInSetupError { return setupError.message }
    return authErrorMessage(for: error)
}

