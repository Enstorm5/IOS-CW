import SwiftUI

// Settings screen
struct SettingsView: View {
    let session: SessionStore
    let profile: UserProfile
    let localStore: LocalStore
    let appLock: AppLockStore
    let crewStore: CrewStore
    let statsStore: StatsStore
    let notifications: NotificationService
    @Binding var settings: UserSettings

    @Environment(\.openURL) private var openURL
    @State private var isConfirmingSignOut = false
    @State private var unsentDraftCount = 0
    @State private var errorMessage: String?
    @State private var isAllowedBySystem = true

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

                Text("Notifications")
                    .font(.auraSectionLabel)
                    .foregroundStyle(Color.auraMuted)
                questRemindersRow

                Text("Privacy")
                    .font(.auraSectionLabel)
                    .foregroundStyle(Color.auraMuted)
                appLockRow
                rankingsRow
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
    }

    @ViewBuilder
    // Face ID lock
    private var appLockRow: some View {
        let unavailable = appLock.biometric.unavailableMessage()
        VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
            Toggle(isOn: Binding(
                get: { settings.appLockEnabled },
                set: { newValue in Task { await changeAppLock(to: newValue) } }
            )) {
                Text("Lock with \(appLock.methodName)")
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
            }
            .disabled(unavailable != nil && !settings.appLockEnabled)

            Text(unavailable ?? "Asks for \(appLock.methodName) when you open Aura or return after \(Int(appLockIntervalSeconds)) seconds away. It only protects this app on this phone.")
                .font(.auraErrorText)
                .foregroundStyle(Color.auraMuted)
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
    }

    // Quest reminders
    private var questRemindersRow: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
            Toggle(isOn: Binding(
                get: { settings.questRemindersEnabled },
                set: { newValue in Task { await changeQuestReminders(to: newValue) } }
            )) {
                Text("Quest reminders")
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
            }
            .tint(Color.auraMint)

            Text("A note each morning with today's quests, and an evening reminder if some are left or your streak is about to end. Reminders are scheduled on this phone only.")
                .font(.auraErrorText)
                .foregroundStyle(Color.auraMuted)

            if let warning = notificationDeniedMessage(isEnabled: settings.questRemindersEnabled, isAllowedBySystem: isAllowedBySystem) {
                Text(warning)
                    .font(.auraErrorText)
                    .foregroundStyle(Color.auraError)
                Button("Open iOS Settings", action: openSystemSettings)
                    .font(.auraLink)
                    .foregroundStyle(Color.auraText)
                    .frame(minHeight: AuraSize.minTap)
            }
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
        .task { isAllowedBySystem = await notifications.isAllowedBySystem() }
    }

    private func changeQuestReminders(to enabled: Bool) async {
        errorMessage = nil
        if enabled {
            let granted = await notifications.requestAuthorization()
            isAllowedBySystem = granted
            settings.questRemindersEnabled = true
            if !granted {
                errorMessage = "Allow notifications for Aura in iOS Settings to get quest reminders."
            }
        } else {
            settings.questRemindersEnabled = false
        }
    }

    // Rankings opt-in
    private var rankingsRow: some View {
        let isInCrew = crewStore.crew != nil
        return VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
            Toggle(isOn: Binding(
                get: { crewStore.me?.showOnRankings ?? false },
                set: { newValue in
                    Task { await crewStore.setRankingOptIn(newValue, stats: statsStore.stats) }
                }
            )) {
                Text("Show me on crew rankings")
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
            }
            .tint(Color.auraMint)
            .disabled(!isInCrew || crewStore.me == nil || crewStore.isWorking)

            Text(rankingSettingDetail(isInCrew: isInCrew))
                .font(.auraErrorText)
                .foregroundStyle(Color.auraMuted)

            if let rankingError = crewStore.actionError {
                ErrorMessage(text: rankingError)
            }
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
    }

    private func changeAppLock(to enabled: Bool) async {
        errorMessage = nil
        let reason = enabled ? "Turn on app lock" : "Turn off app lock"
        let outcome = await appLock.confirmIdentity(reason: reason)
        if outcome == .success {
            settings.appLockEnabled = enabled
        } else {
            errorMessage = lockScreenMessage(outcome: outcome)
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

// Delete account
struct DeleteAccountView: View {
    let session: SessionStore
    let profile: UserProfile
    let localStore: LocalStore

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var needsPassword: Bool {
        deleteAccountNeedsPassword(session.signInMethod)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                Text("This can't be undone.")
                    .font(.auraHeading)
                    .foregroundStyle(Color.auraText)
                Text("Deleting your account removes your profile, every message and drawing you posted, and every wall you placed, including its map. Your login is deleted last. Your points stats stay as anonymous counts.")
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraMuted)

                if needsPassword {
                    AuraTextField(title: "Password", text: $password, isSecure: true)
                        .textContentType(.password)
                } else {
                    Text("You'll be asked to sign in with Google again to confirm.")
                        .font(.auraNotice)
                        .foregroundStyle(Color.auraMuted)
                }
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
                .disabled(isDeleting || (needsPassword && password.isEmpty) || deleteAccountConfirmationError(typed: confirmation) != nil)
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
            try await session.deleteAccount(password: needsPassword ? password : nil, userID: profile.id)
            try? localStore.deleteAccountData(accountID: profile.id)
        } catch is SignInCancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}
