import Testing
@testable import Aura

@MainActor
struct AuthValidationTests {

    @Test func acceptsNormalEmail() {
        #expect(emailValidationError("  person@example.com ") == nil)
    }

    @Test(arguments: ["", "   ", "person", "person@", "@example.com", "person@example", "person@.com", "person@example.", "a b@example.com", "a@b@example.com"])
    func rejectsBadEmail(_ email: String) {
        #expect(emailValidationError(email) != nil)
    }

    @Test func passwordLengthBoundary() {
        #expect(newPasswordValidationError(String(repeating: "a", count: minimumPasswordLength - 1)) != nil)
        #expect(newPasswordValidationError(String(repeating: "a", count: minimumPasswordLength)) == nil)
        #expect(newPasswordValidationError("") != nil)
    }

    @Test func logInOnlyNeedsSomePassword() {
        #expect(logInPasswordValidationError("") != nil)
        #expect(logInPasswordValidationError("abc") == nil)
    }

    @Test func displayNameBoundariesIgnoreSurroundingSpaces() {
        #expect(displayNameValidationError(" a ") != nil)
        #expect(displayNameValidationError(" ab ") == nil)
        #expect(displayNameValidationError(String(repeating: "x", count: 30)) == nil)
        #expect(displayNameValidationError(String(repeating: "x", count: 31)) != nil)
        #expect(displayNameValidationError("   ") != nil)
    }

    @Test func interestsNeedAtLeastOne() {
        #expect(interestsValidationError([]) != nil)
        #expect(interestsValidationError([.parks]) == nil)
    }
}
