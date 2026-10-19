import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            AuraNightBackground()
            VStack(spacing: 8) {
                AuraLogo()
                Text("Aura")
                    .font(.largeTitle.weight(.heavy))
                Text("Write on the city.")
                    .opacity(0.75)
                ProgressView()
                    .tint(.white)
                    .padding(.top, 24)
            }
            .foregroundStyle(.white)
        }
    }
}

#Preview {
    SplashView()
}
