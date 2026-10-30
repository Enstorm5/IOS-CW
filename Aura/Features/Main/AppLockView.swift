import SwiftUI

// Lock screen
struct AppLockView: View {
    let lock: AppLockStore
    let onSignOut: () -> Void

    var body: some View {
        ZStack {
            AuraNightBackground()
            VStack(spacing: AuraSpacing.medium) {
                Spacer()
                AuraLogo()
                Text("Aura is locked")
                    .font(.auraHeading)
                Text("Use \(lock.methodName) to continue.")
                    .opacity(0.75)
                if let message = lock.message {
                    Text(message)
                        .font(.auraNotice)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                Button("Unlock") {
                    Task { await lock.unlock() }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
                .disabled(lock.isAuthenticating)
                Button("Sign out", action: onSignOut)
                    .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
            }
            .foregroundStyle(.white)
            .padding(AuraSpacing.screen)
        }
        .task {
            if lock.isLocked {
                await lock.unlock()
            }
        }
    }
}

// Hide app preview
struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            AuraNightBackground()
            AuraLogo()
        }
    }
}
