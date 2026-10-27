import SwiftUI

struct SettingsView: View {
    let session: SessionStore
    let profile: UserProfile
    let localStore: LocalStore
    @Binding var settings: UserSettings

    @Environment(\.openURL) private var openURL
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingReset = false
    @State private var unsentDraftCount = 0
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                Text("Appearance")
                    .font(.auraSectionLabel)
                    .foregroundStyle(Color.auraMuted)
                Picker("Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings) {
                    do {
                        try localStore.saveSettings(settings, accountID: profile.id)
                    } catch {
                        errorMessage = "Couldn't save the theme."
                    }
                }

                Text("Privacy")
                    .font(.auraSectionLabel)
                    .foregroundStyle(Color.auraMuted)
                Button(action: openSystemSettings) {
                    ProfileLinkRow(systemImage: "location", title: "Location and camera", detail: "Change permissions in iOS Settings")
                }
                .buttonStyle(.plain)

                Text("Account")
                    .font(.auraSectionLabel)
                    .foregroundStyle(Color.auraMuted)
                if let email = session.currentEmail {
                    Text("Signed in as \(email)")
                        .font(.auraNotice)
                        .foregroundStyle(Color.auraText)
                }

                if let errorMessage {
                    ErrorMessage(text: errorMessage)
                }

                Button("Sign out") {
                    unsentDraftCount = localStore.draftCount(accountID: profile.id)
                    isConfirmingSignOut = true
                }
                .buttonStyle(AuraButtonStyle(kind: .outline))

                NavigationLink {
                    DeleteAccountView(session: session, profile: profile, localStore: localStore)
                } label: {
                    Text("Delete account")
                        .font(.auraLink)
                        .foregroundStyle(Color.auraError)
                        .frame(maxWidth: .infinity, minHeight: AuraSize.minTap)
                }

                Button("Development: reset local data") {
                    isConfirmingReset = true
                }
                .font(.auraLink)
                .foregroundStyle(Color.auraMuted)
                .frame(maxWidth: .infinity, minHeight: AuraSize.minTap)
            }
            .padding(AuraSpacing.screen)
        }
        .background(Color.auraBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign out of Aura?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button(unsentDraftCount > 0 ? "Delete drafts and sign out" : "Sign out", role: .destructive) {
                signOut()
            }
        } message: {
            Text(signOutMessage(unsentDraftCount: unsentDraftCount))
        }
        .confirmationDialog("Reset local data?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                do {
                    try localStore.deleteEverything()
                } catch {
                    errorMessage = "Couldn't reset local data."
                }
            }
        } message: {
            Text("Deletes all drafts and saved walls and messages on this phone. Nothing online changes.")
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func signOut() {
        do {
            try localStore.deleteAccountData(accountID: profile.id)
            try session.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DeleteAccountView: View {
    let session: SessionStore
    let profile: UserProfile
    let localStore: LocalStore

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                Text("This can't be undone.")
                    .font(.auraHeading)
                    .foregroundStyle(Color.auraText)
                Text("Deleting your account removes your profile, every message and drawing you posted, and every wall you placed, including its map. Your login is deleted last. Your points stats stay as anonymous counts.")
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraMuted)

                AuraTextField(title: "Password", text: $password, isSecure: true)
                    .textContentType(.password)
                AuraTextField(title: "Type DELETE to confirm", text: $confirmation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                if let errorMessage {
                    ErrorMessage(text: errorMessage)
                }

                Button(role: .destructive) {
                    Task { await deleteAccount() }
                } label: {
                    if isDeleting {
                        ProgressView().tint(Color.auraBackground)
                    } else {
                        Text("Delete my account")
                    }
                }
                .buttonStyle(AuraButtonStyle())
                .disabled(isDeleting || password.isEmpty || deleteAccountConfirmationError(typed: confirmation) != nil)
            }
            .padding(AuraSpacing.screen)
        }
        .background(Color.auraBackground)
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isDeleting)
    }

    private func deleteAccount() async {
        errorMessage = nil
        isDeleting = true
        do {
            try await session.deleteAccount(password: password, userID: profile.id)
            try? localStore.deleteAccountData(accountID: profile.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}
