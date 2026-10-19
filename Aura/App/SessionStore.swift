import Foundation
import Observation
import FirebaseAuth

enum SessionState: Equatable {
    case loading
    case signedOut
    case needsOnboarding(userID: String, suggestedName: String)
    case signedIn(UserProfile)
    case failed(message: String)
}

struct UserFacingError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor @Observable
final class SessionStore {
    private(set) var state: SessionState = .loading

    private let authService: AuthService
    private let profileService: ProfileService
    private var listenerHandle: AuthStateDidChangeListenerHandle?

    private var latestLoadID = 0

    init(authService: AuthService, profileService: ProfileService) {
        self.authService = authService
        self.profileService = profileService
    }

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

    func sendPasswordReset(email: String) async throws {
        do {
            try await authService.sendPasswordReset(email: email)
        } catch {
            throw UserFacingError(message: authErrorMessage(for: error))
        }
    }

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
