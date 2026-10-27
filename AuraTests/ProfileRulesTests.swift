import Testing
import SwiftUI
@testable import Aura

@MainActor
struct ProfileRulesTests {
    let profile = UserProfile(id: "u1", displayName: "Nimal", bio: "old", avatarPreset: .mint, interests: [.cafes])

    @Test func bioLimitIgnoresSurroundingSpaces() {
        #expect(bioValidationError("") == nil)
        #expect(bioValidationError(String(repeating: "a", count: maximumBioLength)) == nil)
        #expect(bioValidationError("  " + String(repeating: "a", count: maximumBioLength) + "  ") == nil)
        #expect(bioValidationError(String(repeating: "a", count: maximumBioLength + 1)) != nil)
    }

    @Test func editedProfileTrimsAndKeepsInterestOrder() throws {
        let updated = try editedProfile(profile, displayName: "  Kamal  ", bio: "  hello  ", avatar: .night, interests: [.parks, .cafes])
        #expect(updated.id == "u1")
        #expect(updated.displayName == "Kamal")
        #expect(updated.bio == "hello")
        #expect(updated.avatarPreset == .night)
        #expect(updated.interests == [.cafes, .parks])
    }

    @Test func editedProfileRejectsBadInput() {
        #expect(throws: UserFacingError.self) { try editedProfile(profile, displayName: "A", bio: "", avatar: .mint, interests: [.cafes]) }
        #expect(throws: UserFacingError.self) { try editedProfile(profile, displayName: "Kamal", bio: String(repeating: "x", count: 161), avatar: .mint, interests: [.cafes]) }
        #expect(throws: UserFacingError.self) { try editedProfile(profile, displayName: "Kamal", bio: "", avatar: .mint, interests: []) }
    }

    @Test func deleteNeedsTheWordDelete() {
        #expect(deleteAccountConfirmationError(typed: "DELETE") == nil)
        #expect(deleteAccountConfirmationError(typed: " delete ") == nil)
        #expect(deleteAccountConfirmationError(typed: "del") != nil)
        #expect(deleteAccountConfirmationError(typed: "") != nil)
    }

    @Test func themeMapsToColorScheme() {
        #expect(colorScheme(for: .system) == nil)
        #expect(colorScheme(for: .light) == .light)
        #expect(colorScheme(for: .dark) == .dark)
        #expect(AppTheme.allCases.map(\.title) == ["System", "Light", "Dark"])
    }
}
