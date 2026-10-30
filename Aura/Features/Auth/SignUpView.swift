import SwiftUI

// Sign up form
struct SignUpView: View {
    let session: SessionStore
    let onLogInInstead: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showFieldErrors = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                Text("Create account")
                    .font(.auraScreenTitle)
                    .foregroundStyle(Color.auraText)
                    .padding(.bottom, AuraSpacing.small)

                AuraTextField(title: "Email", text: $email, error: fieldError(emailValidationError(email)))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                AuraTextField(title: "Password", text: $password, error: fieldError(newPasswordValidationError(password)), isSecure: true)
                    .textContentType(.newPassword)

                AuraTextField(title: "Display name", text: $displayName, error: fieldError(displayNameValidationError(displayName)))
                    .textContentType(.nickname)

                if let errorMessage {
                    ErrorMessage(text: errorMessage)
                }

                Button {
                    Task { await signUp() }
                } label: {
                    if isWorking {
                        ProgressView().tint(Color.auraBackground)
                    } else {
                        Text("Sign up")
                    }
                }
                .buttonStyle(AuraButtonStyle())
                .disabled(isWorking)
                .padding(.top, AuraSpacing.small)

                Button("I already have an account", action: onLogInInstead)
                    .font(.auraLink)
                    .foregroundStyle(Color.auraText)
                    .frame(maxWidth: .infinity, minHeight: AuraSize.minTap)
            }
            .padding(AuraSpacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.auraBackground)
    }

    private func fieldError(_ error: String?) -> String? {
        showFieldErrors ? error : nil
    }

    private func signUp() async {
        showFieldErrors = true
        guard emailValidationError(email) == nil,
              newPasswordValidationError(password) == nil,
              displayNameValidationError(displayName) == nil else { return }

        isWorking = true
        errorMessage = nil
        do {
            try await session.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
