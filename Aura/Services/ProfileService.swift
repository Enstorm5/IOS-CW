import Foundation
import FirebaseFirestore

final class ProfileService {
    private let profiles = Firestore.firestore().collection("profiles")

    func fetchProfile(userID: String) async throws -> UserProfile? {
        let snapshot = try await profiles.document(userID).getDocument()
        guard let fields = snapshot.data() else { return nil }
        return userProfile(id: userID, fields: fields)
    }

    func createProfile(_ profile: UserProfile) async throws {
        var fields = firestoreFields(for: profile)
        fields["createdAt"] = FieldValue.serverTimestamp()
        try await profiles.document(profile.id).setData(fields)
    }

    func updateProfile(_ profile: UserProfile) async throws {
        try await profiles.document(profile.id).updateData(firestoreFields(for: profile))
    }
}

func firestoreFields(for profile: UserProfile) -> [String: Any] {
    [
        "displayName": profile.displayName,
        "bio": profile.bio,
        "avatarPreset": profile.avatarPreset.rawValue,
        "interests": profile.interests.map(\.rawValue),
    ]
}

func userProfile(id: String, fields: [String: Any]) -> UserProfile? {
    guard let displayName = fields["displayName"] as? String else { return nil }
    let interestValues = fields["interests"] as? [String] ?? []
    let avatarValue = fields["avatarPreset"] as? String ?? ""

    return UserProfile(
        id: id,
        displayName: displayName,
        bio: fields["bio"] as? String ?? "",
        avatarPreset: AvatarPreset(rawValue: avatarValue) ?? .magenta,
        interests: interestValues.compactMap { Interest(rawValue: $0) }
    )
}
