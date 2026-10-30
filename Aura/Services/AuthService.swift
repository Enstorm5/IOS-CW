import Foundation
import FirebaseAuth

final class AuthService {
    private let auth = Auth.auth()

    var currentUserID: String? { auth.currentUser?.uid }
    var currentDisplayName: String? { auth.currentUser?.displayName }
    var currentEmail: String? { auth.currentUser?.email }

    // Auth listener
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

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    func signOut() throws {
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
    case .operationNotAllowed:
        return "Email sign-in isn't turned on for this app yet."
    default:
        return "Something went wrong. Please try again."
    }
}
