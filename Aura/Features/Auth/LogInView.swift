import SwiftUI

// Log in form
struct LogInView: View {
    let session: SessionStore
    let onForgotPassword: () -> Void
    let onSignUpInstead: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var showFieldErrors = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                Text("Welcome back")
                    .font(.auraScreenTitle)
                    .foregroundStyle(Color.auraText)
                    .padding(.bottom, AuraSpacing.small)

                AuraTextField(title: "Email", text: $email, error: fieldError(emailValidationError(email)))
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                AuraTextField(title: "Password", text: $password, error: fieldError(logInPasswordValidationError(password)), isSecure: true)
                    .textContentType(.password)

                Button("Forgot password?", action: onForgotPassword)
                    .font(.auraLink)
                    .foregroundStyle(Color.auraText)
                    .frame(minHeight: AuraSize.minTap)

                if let errorMessage {
                    ErrorMessage(text: errorMessage)
                }

                Button {
                    Task { await logIn() }
                } label: {
                    if isWorking {
                        ProgressView().tint(Color.auraBackground)
                    } else {
                        Text("Log in")
                    }
                }
                .buttonStyle(AuraButtonStyle())
                .disabled(isWorking)

                GoogleSignInButton(session: session)

                Button("Create an account", action: onSignUpInstead)
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

    private func logIn() async {
        showFieldErrors = true
        guard emailValidationError(email) == nil, logInPasswordValidationError(password) == nil else { return }

        isWorking = true
        errorMessage = nil
        do {
            try await session.logIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
