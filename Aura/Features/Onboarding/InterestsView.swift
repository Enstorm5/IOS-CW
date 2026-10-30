import SwiftUI

// Name and interests
struct InterestsView: View {
    let session: SessionStore
    let suggestedName: String
    let onContinue: (OnboardingChoices) -> Void

    @State private var typedName = ""
    @State private var selectedInterests: Set<Interest> = []
    @State private var avatar: AvatarPreset = .magenta
    @State private var showFieldErrors = false
    @State private var errorMessage: String?

    private var needsNameField: Bool {
        displayNameValidationError(suggestedName) != nil
    }

    private var chosenName: String {
        needsNameField ? typedName : suggestedName
    }

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: AuraSpacing.small)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                Text("What do you like?")
                    .font(.auraScreenTitle)
                    .foregroundStyle(Color.auraText)
                Text("Pick at least one.")
                    .foregroundStyle(Color.auraMuted)

                if needsNameField {
                    AuraTextField(title: "Display name", text: $typedName, error: showFieldErrors ? displayNameValidationError(typedName) : nil)
                        .textContentType(.nickname)
                }

                LazyVGrid(columns: columns, spacing: AuraSpacing.small) {
                    ForEach(Interest.allCases) { interest in
                        ChipToggle(title: interest.title, isSelected: selectedInterests.contains(interest)) {
                            toggle(interest)
                        }
                    }
                }

                if showFieldErrors, let interestsError = interestsValidationError(selectedInterests) {
                    ErrorMessage(text: interestsError)
                }

                Text("Pick your explorer look")
                    .font(.auraSectionLabel)
                    .foregroundStyle(Color.auraMuted)
                    .padding(.top, AuraSpacing.medium)

                HStack(spacing: AuraSpacing.large) {
                    ForEach(AvatarPreset.allCases) { preset in
                        Button {
                            avatar = preset
                        } label: {
                            AvatarView(preset: preset, size: 56)
                                .padding(AuraSpacing.xxSmall)
                                .overlay {
                                    Circle().strokeBorder(Color.auraText, lineWidth: avatar == preset ? 3 : 0)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(avatar == preset ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)

                if let errorMessage {
                    ErrorMessage(text: errorMessage)
                }

                Button("Continue", action: continueTapped)
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
                    .padding(.top, AuraSpacing.medium)

                Button("Sign out") {
                    do {
                        try session.signOut()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .font(.auraLink)
                .foregroundStyle(Color.auraText)
                .frame(maxWidth: .infinity, minHeight: AuraSize.minTap)
            }
            .padding(AuraSpacing.screen)
        }
        .background(Color.auraBackground)
    }

    private func toggle(_ interest: Interest) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
    }

    private func continueTapped() {
        showFieldErrors = true
        guard displayNameValidationError(chosenName) == nil,
              interestsValidationError(selectedInterests) == nil else { return }

        onContinue(OnboardingChoices(
            displayName: chosenName.trimmingCharacters(in: .whitespacesAndNewlines),
            interests: Interest.allCases.filter { selectedInterests.contains($0) },
            avatar: avatar
        ))
    }
}
