import SwiftUI

struct EditProfileView: View {
    let session: SessionStore
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var bio: String
    @State private var avatar: AvatarPreset
    @State private var interests: Set<Interest>
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: AuraSpacing.small)]

    init(session: SessionStore, profile: UserProfile) {
        self.session = session
        self.profile = profile
        _displayName = State(initialValue: profile.displayName)
        _bio = State(initialValue: profile.bio)
        _avatar = State(initialValue: profile.avatarPreset)
        _interests = State(initialValue: Set(profile.interests))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                AuraTextField(title: "Display name", text: $displayName, error: displayNameValidationError(displayName))
                    .textContentType(.nickname)

                AuraTextField(title: "Bio (optional)", text: $bio, error: bioValidationError(bio))
                Text("\(bio.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(maximumBioLength)")
                    .font(.auraErrorText)
                    .foregroundStyle(Color.auraMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("Your look")
                    .font(.auraSectionLabel)
                    .foregroundStyle(Color.auraMuted)
                HStack(spacing: AuraSpacing.large) {
                    ForEach(AvatarPreset.allCases) { preset in
                        Button {
                            avatar = preset
                        } label: {
                            AvatarView(preset: preset, size: AuraSize.avatarChoice)
                                .padding(AuraSpacing.xxSmall)
                                .overlay {
                                    Circle().strokeBorder(Color.auraText, lineWidth: avatar == preset ? AuraSize.pinBorder : 0)
                                }
                        }
                        .buttonStyle(AuraBounceButtonStyle())
                        .accessibilityAddTraits(avatar == preset ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)

                Text("Interests")
                    .font(.auraSectionLabel)
                    .foregroundStyle(Color.auraMuted)
                LazyVGrid(columns: columns, spacing: AuraSpacing.small) {
                    ForEach(Interest.allCases) { interest in
                        ChipToggle(title: interest.title, isSelected: interests.contains(interest)) {
                            if interests.contains(interest) {
                                interests.remove(interest)
                            } else {
                                interests.insert(interest)
                            }
                        }
                    }
                }
                if let interestsError = interestsValidationError(interests) {
                    ErrorMessage(text: interestsError)
                }

                if let errorMessage {
                    ErrorMessage(text: errorMessage)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().tint(Color.auraInk)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
                .disabled(isSaving)

                Text("Messages you already posted keep the name they were posted with.")
                    .font(.auraErrorText)
                    .foregroundStyle(Color.auraMuted)
            }
            .padding(AuraSpacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.auraBackground)
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        do {
            let updated = try editedProfile(profile, displayName: displayName, bio: bio, avatar: avatar, interests: interests)
            try await session.updateProfile(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
