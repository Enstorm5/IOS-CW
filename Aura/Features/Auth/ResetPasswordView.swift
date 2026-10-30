import SwiftUI

// Password reset
struct ResetPasswordView: View {
    let session: SessionStore

    @State private var email = ""
    @State private var showFieldErrors = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var didSend = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                Text("Reset password")
                    .font(.auraScreenTitle)
                    .foregroundStyle(Color.auraText)
                Text("Enter your account email and we'll send you a link to choose a new password.")
                    .foregroundStyle(Color.auraMuted)
                    .padding(.bottom, AuraSpacing.small)

                AuraTextField(title: "Email", text: $email, error: showFieldErrors ? emailValidationError(email) : nil)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let errorMessage {
                    ErrorMessage(text: errorMessage)
                }

                if didSend {
                    Label("If an account uses that email, a reset link is on its way.", systemImage: "envelope.badge")
                        .font(.auraNotice)
                        .foregroundStyle(Color.auraText)
                }

                Button {
                    Task { await sendReset() }
                } label: {
                    if isWorking {
                        ProgressView().tint(Color.auraBackground)
                    } else {
                        Text(didSend ? "Send again" : "Send reset link")
                    }
                }
                .buttonStyle(AuraButtonStyle())
                .disabled(isWorking)
                .padding(.top, AuraSpacing.small)
            }
            .padding(AuraSpacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.auraBackground)
    }

    private func sendReset() async {
        showFieldErrors = true
        guard emailValidationError(email) == nil else { return }

        isWorking = true
        errorMessage = nil
        do {
            try await session.sendPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            didSend = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
