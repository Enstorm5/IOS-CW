import SwiftUI

struct InterestsView: View {
    let session: SessionStore
    let userID: String

    @State private var displayName: String
    @State private var selectedInterests: Set<Interest> = []
    @State private var avatar: AvatarPreset = .magenta
    @State private var showFieldErrors = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let needsNameField: Bool

    init(session: SessionStore, userID: String, suggestedName: String) {
        self.session = session
        self.userID = userID
        _displayName = State(initialValue: suggestedName)
        needsNameField = displayNameValidationError(suggestedName) != nil
    }

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("What do you like?")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Color.auraText)
                Text("Pick at least one.")
                    .foregroundStyle(Color.auraMuted)

                if needsNameField {
                    AuraTextField(title: "Display name", text: $displayName, error: showFieldErrors ? displayNameValidationError(displayName) : nil)
                        .textContentType(.nickname)
                }

                LazyVGrid(columns: columns, spacing: 8) {
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
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.auraMuted)
                    .padding(.top, 12)

                HStack(spacing: 16) {
                    ForEach(AvatarPreset.allCases) { preset in
                        Button {
                            avatar = preset
                        } label: {
                            AvatarView(preset: preset, size: 56)
                                .padding(4)
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

                Button {
                    Task { await finish() }
                } label: {
                    if isWorking {
                        ProgressView().tint(Color.auraInk)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
                .disabled(isWorking)
                .padding(.top, 12)

                Button("Sign out") {
                    do {
                        try session.signOut()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.auraText)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(20)
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

    private func finish() async {
        showFieldErrors = true
        guard displayNameValidationError(displayName) == nil,
              interestsValidationError(selectedInterests) == nil else { return }

        isWorking = true
        errorMessage = nil
        do {
            let interests = Interest.allCases.filter { selectedInterests.contains($0) }
            try await session.completeOnboarding(
                userID: userID,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                interests: interests,
                avatar: avatar
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
