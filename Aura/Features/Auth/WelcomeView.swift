import SwiftUI

private struct IntroPage {
    let chip: String
    let title: String
    let message: String
}

private let introPages = [
    IntroPage(chip: "Find", title: "Walls are hiding everywhere", message: "Walk around, spot glowing walls and read what strangers left."),
    IntroPage(chip: "Write", title: "Leave your mark", message: "Add a message to a wall for the next person who finds it."),
    IntroPage(chip: "Earn", title: "Explore to earn points", message: "Discover new walls to earn points, then spend them on walls of your own."),
]

struct WelcomeView: View {
    let onFinish: () -> Void
    let onLogIn: () -> Void

    @State private var pageIndex = 0

    private var isLastPage: Bool { pageIndex == introPages.count - 1 }

    var body: some View {
        ZStack {
            AuraNightBackground()

            VStack(spacing: AuraSpacing.small) {
                TabView(selection: $pageIndex) {
                    ForEach(introPages.indices, id: \.self) { index in
                        IntroPageView(page: introPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(isLastPage ? "Get started" : "Next") {
                    if isLastPage {
                        onFinish()
                    } else {
                        withAnimation { pageIndex += 1 }
                    }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))

                if !isLastPage {
                    Button("Skip", action: onFinish)
                        .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
                }

                Button("I already have an account", action: onLogIn)
                    .font(.auraLink)
                    .foregroundStyle(.white)
                    .frame(minHeight: AuraSize.minTap)
            }
            .padding(.horizontal, AuraSpacing.screen)
            .padding(.bottom, AuraSpacing.small)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct IntroPageView: View {
    let page: IntroPage

    var body: some View {
        VStack(spacing: AuraSpacing.medium) {
            AuraPill(text: page.chip)
            Text(page.title)
                .font(.auraHeading)
            Text(page.message)
                .opacity(0.75)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(.horizontal, AuraSpacing.medium)
    }
}

#Preview {
    WelcomeView(onFinish: {}, onLogIn: {})
}
