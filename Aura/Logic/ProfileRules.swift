import Foundation

let maximumBioLength = 160

func bioValidationError(_ bio: String) -> String? {
    bio.trimmingCharacters(in: .whitespacesAndNewlines).count > maximumBioLength
        ? "Keep your bio to \(maximumBioLength) characters or fewer."
        : nil
}

func editedProfile(_ profile: UserProfile, displayName: String, bio: String, avatar: AvatarPreset, interests: Set<Interest>) throws -> UserProfile {
    let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
    if let error = displayNameValidationError(cleanedName) ?? bioValidationError(cleanedBio) ?? interestsValidationError(interests) {
        throw UserFacingError(message: error)
    }
    var updated = profile
    updated.displayName = cleanedName
    updated.bio = cleanedBio
    updated.avatarPreset = avatar
    updated.interests = Interest.allCases.filter { interests.contains($0) }
    return updated
}

func deleteAccountConfirmationError(typed: String) -> String? {
    typed.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE" ? nil : "Type DELETE to confirm."
}
