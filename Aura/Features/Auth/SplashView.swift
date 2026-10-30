import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            AuraNightBackground()
            VStack(spacing: AuraSpacing.small) {
                AuraLogo(size: AuraSize.splashLogo, font: .auraSplashLogo, cornerRadius: AuraRadius.splashLogo)
                Text("Aura")
                    .font(.auraSplashTitle)
                Text("Write on the city.")
                    .font(.auraSplashTagline)
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
