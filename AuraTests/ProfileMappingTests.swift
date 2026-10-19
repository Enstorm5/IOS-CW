import Testing
@testable import Aura

@MainActor
struct ProfileMappingTests {

    @Test func roundTripKeepsAllFields() {
        let profile = UserProfile(id: "u1", displayName: "Nimal", bio: "Hi", avatarPreset: .mint, interests: [.cafes, .streetArt])
        let fields = firestoreFields(for: profile)
        #expect(userProfile(id: "u1", fields: fields) == profile)
    }

    @Test func missingDisplayNameMeansNoProfile() {
        #expect(userProfile(id: "u1", fields: ["interests": ["cafes"]]) == nil)
    }

    @Test func unknownValuesAreSkippedOrDefaulted() {
        let fields: [String: Any] = [
            "displayName": "Nimal",
            "avatarPreset": "rainbow",
            "interests": ["cafes", "skydiving"],
        ]
        let profile = userProfile(id: "u1", fields: fields)
        #expect(profile?.avatarPreset == .magenta)
        #expect(profile?.interests == [.cafes])
        #expect(profile?.bio == "")
    }
}
