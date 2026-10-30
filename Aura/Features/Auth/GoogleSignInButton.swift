import SwiftUI

// Google sign-in button
struct GoogleSignInButton: View {
    let session: SessionStore

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            Text("or")
                .font(.auraNotice)
                .foregroundStyle(Color.auraMuted)
                .frame(maxWidth: .infinity)

            if let errorMessage {
                ErrorMessage(text: errorMessage)
            }

            Button {
                Task { await signIn() }
            } label: {
                if isWorking {
                    ProgressView().tint(Color.auraText)
                } else {
                    Text("Continue with Google")
                }
            }
            .buttonStyle(AuraButtonStyle(kind: .outline))
            .disabled(isWorking)
        }
    }

    private func signIn() async {
        isWorking = true
        errorMessage = nil
        do {
            try await session.logInWithGoogle()
        } catch is SignInCancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
