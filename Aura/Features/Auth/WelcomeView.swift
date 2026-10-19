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

            VStack(spacing: 8) {
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
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct IntroPageView: View {
    let page: IntroPage

    var body: some View {
        VStack(spacing: 10) {
            Text(page.chip)
                .font(.footnote.weight(.heavy))
                .foregroundStyle(Color.auraInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.auraYellow, in: .capsule)
            Text(page.title)
                .font(.title.weight(.heavy))
            Text(page.message)
                .opacity(0.75)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
    }
}

#Preview {
    WelcomeView(onFinish: {}, onLogIn: {})
}
