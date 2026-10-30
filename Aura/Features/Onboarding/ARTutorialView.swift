import SwiftUI
import ARKit

struct ARTutorialView: View {
    let isSaving: Bool
    let errorMessage: String?
    let onFinish: () -> Void

    @State private var isPracticing = false
    @State private var didPlaceWall = false
    @State private var cameraFailed = false

    private let isARSupported = ARWorldTrackingConfiguration.isSupported

    var body: some View {
        ZStack {
            if isPracticing && !cameraFailed {
                PracticeARView(
                    onPlaced: { didPlaceWall = true },
                    onFailed: { cameraFailed = true }
                )
                .ignoresSafeArea()
            } else {
                AuraNightBackground()
            }

            VStack(spacing: AuraSpacing.medium) {
                HStack {
                    Text("Try it")
                        .font(.auraHeading)
                        .foregroundStyle(.white)
                    Spacer()
                }

                if isPracticing && !cameraFailed {
                    if didPlaceWall {
                        Spacer()
                        congratulations
                    } else {
                        AuraPill(text: "Point at a flat wall, then tap it")
                        Spacer()
                    }
                } else {
                    Spacer()
                    introduction
                    Spacer()
                }

                if let errorMessage {
                    StatusBanner(systemImage: "exclamationmark.circle", message: errorMessage)
                }

                buttons
            }
            .padding(AuraSpacing.screen)
        }
    }

    // Practice success
    private var congratulations: some View {
        VStack(spacing: AuraSpacing.small) {
            Text("Congratulations!")
                .font(.auraHeading)
                .foregroundStyle(Color.auraText)
            Text("You placed your first wall. You're ready to explore. Real walls near you work just like this one.")
                .font(.auraNotice)
                .foregroundStyle(Color.auraMuted)
                .multilineTextAlignment(.center)
        }
        .padding(AuraSpacing.large)
        .frame(maxWidth: .infinity)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
        .auraPopIn()
        .accessibilityElement(children: .combine)
    }

    private var introduction: some View {
        VStack(spacing: AuraSpacing.medium) {
            AuraPill(text: "AR tutorial")
            Text("Place a practice wall")
                .font(.auraHeading)
            Text(introductionMessage)
                .opacity(0.75)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
    }

    private var introductionMessage: String {
        if cameraFailed {
            return "Aura couldn't use the camera. Allow camera access in Settings, or skip and try AR later."
        }
        if !isARSupported {
            return "This device can't run AR. You can try it later on an iPhone that supports AR."
        }
        return "Point your camera at a flat wall and tap it to place a practice wall. Nothing is saved or shared."
    }

    @ViewBuilder
    private var buttons: some View {
        if isSaving {
            ProgressView()
                .tint(.white)
                .frame(minHeight: AuraSize.control)
        } else if didPlaceWall && !cameraFailed {
            Button("Start exploring", action: onFinish)
                .buttonStyle(AuraButtonStyle(kind: .highlight))
        } else {
            if isARSupported && !isPracticing && !cameraFailed {
                Button("Place practice wall") {
                    isPracticing = true
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
            }
            Button("Skip for now", action: onFinish)
                .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
        }
    }
}
