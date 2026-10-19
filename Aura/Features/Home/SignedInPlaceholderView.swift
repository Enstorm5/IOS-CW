import SwiftUI

struct SignedInPlaceholderView: View {
    let session: SessionStore
    let profile: UserProfile

    @State private var isConfirmingSignOut = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: AuraSpacing.large) {
            Text("Development placeholder: main tabs arrive in P02")
                .font(.auraPill)
                .foregroundStyle(Color.auraInk)
                .padding(.horizontal, AuraSpacing.medium)
                .padding(.vertical, AuraSpacing.xSmall)
                .background(Color.auraYellow, in: .capsule)

            Spacer()

            AvatarView(preset: profile.avatarPreset, size: 88)
            Text("Hi, \(profile.displayName)")
                .font(.auraHeading)
                .foregroundStyle(Color.auraText)
            Text(profile.interests.map(\.title).joined(separator: " · "))
                .foregroundStyle(Color.auraMuted)
                .multilineTextAlignment(.center)

            if let errorMessage {
                ErrorMessage(text: errorMessage)
            }

            Spacer()

            Button("Sign out") {
                isConfirmingSignOut = true
            }
            .buttonStyle(AuraButtonStyle(kind: .outline))
        }
        .padding(AuraSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.auraBackground)
        .confirmationDialog("Sign out of Aura?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                do {
                    try session.signOut()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
