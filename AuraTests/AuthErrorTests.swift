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
