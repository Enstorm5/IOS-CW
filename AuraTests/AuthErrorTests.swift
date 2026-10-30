import Testing
import Foundation
@testable import Aura

@MainActor
struct AuthErrorTests {
    let domain = "FIRAuthErrorDomain"

    func message(code: Int) -> String {
        authErrorMessage(for: NSError(domain: domain, code: code))
    }

    @Test func knownCodesGiveReadableMessages() {
        #expect(message(code: 17008) == "That email doesn't look right.")
        #expect(message(code: 17007) == "An account already uses this email. Try logging in instead.")
        #expect(message(code: 17026) == "That password is too weak. Try a longer one.")
        #expect(message(code: 17009) == "Email or password is incorrect.")
        #expect(message(code: 17011) == "Email or password is incorrect.")
        #expect(message(code: 17004) == "Email or password is incorrect.")
        #expect(message(code: 17005) == "This account has been disabled.")
        #expect(message(code: 17020) == "You're offline. Check your connection and try again.")
        #expect(message(code: 17010) == "Too many attempts. Wait a moment and try again.")
        #expect(message(code: 17006) == "Email sign-in isn't turned on for this app yet.")
    }

    @Test func unknownErrorsGetTheGenericMessage() {
        #expect(message(code: 99999) == "Something went wrong. Please try again.")
        #expect(authErrorMessage(for: NSError(domain: "other", code: 17008)) == "Something went wrong. Please try again.")
        #expect(authErrorMessage(for: UserFacingError(message: "x")) == "Something went wrong. Please try again.")
    }

    @Test func googleCancelIsRecognisedAndOtherErrorsAreNot() {
        #expect(isGoogleSignInCancelled(domain: "com.google.GIDSignIn", code: -5))
        #expect(!isGoogleSignInCancelled(domain: "com.google.GIDSignIn", code: -4))
        #expect(!isGoogleSignInCancelled(domain: "FIRAuthErrorDomain", code: -5))
    }

    @Test func googleSignInMessagesHideCancelAndExplainSetupProblems() {
        let cancelled = NSError(domain: "com.google.GIDSignIn", code: -5)
        #expect(googleSignInErrorMessage(for: cancelled) == nil)
        #expect(googleSignInErrorMessage(for: GoogleSignInSetupError.notConfigured) == "Google sign-in isn't set up for this build yet.")
        #expect(googleSignInErrorMessage(for: GoogleSignInSetupError.noToken) == "Google didn't return a sign-in token. Try again.")
        let offline = NSError(domain: "FIRAuthErrorDomain", code: 17020)
        #expect(googleSignInErrorMessage(for: offline) == "You're offline. Check your connection and try again.")
        #expect(googleSignInErrorMessage(for: NSError(domain: "x", code: 1)) == "Something went wrong. Please try again.")
    }

    @Test func accountsAreClassifiedByTheirProviders() {
        #expect(signInMethodFrom(providerIDs: ["password"]) == .password)
        #expect(signInMethodFrom(providerIDs: ["google.com"]) == .google)
        #expect(signInMethodFrom(providerIDs: ["google.com", "password"]) == .password)
        #expect(signInMethodFrom(providerIDs: ["apple.com"]) == .other)
        #expect(signInMethodFrom(providerIDs: []) == .other)
    }

    @Test func onlyPasswordAccountsNeedAPasswordToDelete() {
        #expect(deleteAccountNeedsPassword(.password))
        #expect(!deleteAccountNeedsPassword(.google))
        #expect(!deleteAccountNeedsPassword(.other))
    }

    @Test func userFacingErrorShowsItsMessage() {
        #expect(UserFacingError(message: "Nope").localizedDescription == "Nope")
    }

    @Test func mapErrorsExplainThemselves() {
        #expect(wallMapErrorMessage(WorldMapArchiveError.corrupt) == worldMapErrorMessage(WorldMapArchiveError.corrupt))
        #expect(wallMapErrorMessage(NSError(domain: "net", code: 1)) == "Couldn't reach the server. Check your connection and try again.")
        for error in [WorldMapArchiveError.exportFailed, .tooLarge, .corrupt, .missingWallAnchor] {
            #expect(!worldMapErrorMessage(error).isEmpty)
        }
    }
}
