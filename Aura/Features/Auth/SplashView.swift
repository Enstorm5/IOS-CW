import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            AuraNightBackground()
            VStack(spacing: AuraSpacing.small) {
                AuraLogo()
                Text("Aura")
                    .font(.auraScreenTitle)
                Text("Write on the city.")
                    .opacity(0.75)
                ProgressView()
                    .tint(.white)
                    .padding(.top, AuraSpacing.xLarge)
            }
            .foregroundStyle(.white)
        }
    }
}

#Preview {
    SplashView()
}
