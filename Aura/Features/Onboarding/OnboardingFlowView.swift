import SwiftUI

struct OnboardingChoices {
    var displayName: String
    var interests: [Interest]
    var avatar: AvatarPreset
}

enum OnboardingStep {
    case interests
    case permissions
    case arTutorial
}

// Onboarding steps
struct OnboardingFlowView: View {
    let session: SessionStore
    let userID: String
    let suggestedName: String
    let locationService: LocationService

    @State private var step: OnboardingStep = .interests
    @State private var choices: OnboardingChoices?
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        Group {
            switch step {
            case .interests:
                InterestsView(session: session, suggestedName: choices?.displayName ?? suggestedName) { newChoices in
                    choices = newChoices
                    step = .permissions
                }
            case .permissions:
                PermissionsView(locationService: locationService) {
                    step = .arTutorial
                }
            case .arTutorial:
                ARTutorialView(isSaving: isSaving, errorMessage: saveError) {
                    Task { await finishOnboarding() }
                }
            }
        }
        .animation(.default, value: step)
    }

    private func finishOnboarding() async {
        guard let choices else {
            step = .interests
            return
        }

        isSaving = true
        saveError = nil
        do {
            try await session.completeOnboarding(
                userID: userID,
                displayName: choices.displayName,
                interests: choices.interests,
                avatar: choices.avatar
            )
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}
