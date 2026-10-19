import SwiftUI

struct SignedInPlaceholderView: View {
    let session: SessionStore
    let profile: UserProfile

    @State private var isConfirmingSignOut = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Development placeholder: main tabs arrive in P02")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.auraInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.auraYellow, in: .capsule)

            Spacer()

            AvatarView(preset: profile.avatarPreset, size: 88)
            Text("Hi, \(profile.displayName)")
                .font(.title.weight(.heavy))
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
        .padding(20)
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
