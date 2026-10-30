import Foundation
import Observation
import FirebaseAuth

// Session states
enum SessionState: Equatable {
    case loading
    case signedOut
    case needsOnboarding(userID: String, suggestedName: String)
    case signedIn(UserProfile)
    case failed(message: String)
}

struct SignInCancelled: Error {}

struct UserFacingError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor @Observable
// Signed-in session
final class SessionStore {
    private(set) var state: SessionState = .loading

    private let authService: AuthService
    private let profileService: ProfileService
    private let deletionService: AccountDeletionService
    private var listenerHandle: AuthStateDidChangeListenerHandle?

    private var latestLoadID = 0

    init(authService: AuthService, profileService: ProfileService, deletionService: AccountDeletionService) {
        self.authService = authService
        self.profileService = profileService
        self.deletionService = deletionService
    }

    var currentEmail: String? { authService.currentEmail }
    var signInMethod: SignInMethod { authService.signInMethod }

    func updateProfile(_ profile: UserProfile) async throws {
        do {
            try await profileService.updateProfile(profile)
        } catch {
            throw UserFacingError(message: "Couldn't save your profile. Check your connection and try again.")
        }
        latestLoadID += 1
        state = .signedIn(profile)
    }

    // Delete account steps
    func deleteAccount(password: String?, userID: String) async throws {
        do {
            if authService.signInMethod == .google {
                try await authService.reauthenticateWithGoogle()
            } else {
                try await authService.reauthenticate(password: password ?? "")
            }
        } catch {
            guard let message = googleSignInErrorMessage(for: error) else { throw SignInCancelled() }
            throw UserFacingError(message: message)
        }
        do {
            try await deletionService.deleteContent(userID: userID)
        } catch {
            throw UserFacingError(message: "Couldn't delete your messages and walls. Check your connection and try again. Nothing else was deleted yet.")
        }
        do {
            try await authService.deleteCurrentUser()
        } catch {
            throw UserFacingError(message: "Your content was deleted, but deleting your login failed. Try again.")
        }
        latestLoadID += 1
        state = .signedOut
    }

    // Auth listener
    func start() {
        guard listenerHandle == nil else { return }
        listenerHandle = authService.observeSignIn { [weak self] userID in
            Task { await self?.loadSession(userID: userID) }
        }
    }

    func reload() async {
        await loadSession(userID: authService.currentUserID)
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        do {
            try await authService.signUp(email: email, password: password, displayName: displayName)
        } catch {
            throw UserFacingError(message: authErrorMessage(for: error))
        }
        await reload()
    }

    func logIn(email: String, password: String) async throws {
        do {
            try await authService.logIn(email: email, password: password)
        } catch {
            throw UserFacingError(message: authErrorMessage(for: error))
        }
        await reload()
    }

    // Google log in
    func logInWithGoogle() async throws {
        do {
            try await authService.logInWithGoogle()
        } catch {
            guard let message = googleSignInErrorMessage(for: error) else { throw SignInCancelled() }
            throw UserFacingError(message: message)
        }
        await reload()
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await authService.sendPasswordReset(email: email)
        } catch {
            throw UserFacingError(message: authErrorMessage(for: error))
        }
    }

    // Create profile
    func completeOnboarding(userID: String, displayName: String, interests: [Interest], avatar: AvatarPreset) async throws {
        let profile = UserProfile(id: userID, displayName: displayName, bio: "", avatarPreset: avatar, interests: interests)
        do {
            try await profileService.createProfile(profile)
        } catch {
            throw UserFacingError(message: "We couldn't save your profile. Check your connection and try again.")
        }
        latestLoadID += 1
        state = .signedIn(profile)
    }

    func signOut() throws {
        do {
            try authService.signOut()
        } catch {
            throw UserFacingError(message: "Signing out failed. Please try again.")
        }
        latestLoadID += 1
        state = .signedOut
    }

    // Load profile
    private func loadSession(userID: String?) async {
        latestLoadID += 1
        let loadID = latestLoadID

        guard let userID else {
            state = .signedOut
            return
        }

        do {
            let profile = try await profileService.fetchProfile(userID: userID)
            guard loadID == latestLoadID else { return }
            if let profile {
                state = .signedIn(profile)
            } else {
                state = .needsOnboarding(userID: userID, suggestedName: authService.currentDisplayName ?? "")
            }
        } catch {
            guard loadID == latestLoadID else { return }
            state = .failed(message: "We couldn't load your profile. Check your connection and try again.")
        }
    }
}
