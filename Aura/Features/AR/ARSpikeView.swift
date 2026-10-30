import SwiftUI
import ARKit

// Place wall screen
struct ARSpikeView: View {
    @State private var viewModel: PlaceWallViewModel
    @State private var isNaming = false

    private let isARSupported = ARWorldTrackingConfiguration.isSupported

    init(publisher: WallPublishService, locationService: LocationService, currentUser: UserProfile, statsStore: StatsStore) {
        _viewModel = State(initialValue: PlaceWallViewModel(publisher: publisher, locationService: locationService, currentUser: currentUser, statsStore: statsStore))
    }

    private var arSession: ARSessionService { viewModel.arSession }

    var body: some View {
        ZStack {
            if arSession.isCameraActive {
                ARWallView(service: arSession)
                    .ignoresSafeArea()
            } else {
                AuraNightBackground()
            }

            VStack(alignment: .leading, spacing: AuraSpacing.small) {
                HStack {
                    Text("Place a wall")
                        .font(.auraHeading)
                        .foregroundStyle(.white)
                    Spacer()
                }

                statusLines

                Spacer()

                if arSession.phase == .mapping {
                    WallSizeControls(size: arSession.wallSize) { widthSteps, heightSteps in
                        arSession.stepWallSize(widthSteps: widthSteps, heightSteps: heightSteps)
                    }
                }

                if let publishError = viewModel.publishError, !isNaming {
                    StatusBanner(systemImage: "exclamationmark.triangle", message: publishError)
                }

                bottomControls
            }
            .padding(AuraSpacing.screen)
        }
        .sheet(isPresented: $isNaming, onDismiss: { viewModel.discardCapture() }) {
            NameWallSheet(isPublishing: viewModel.isPublishing, costMessage: viewModel.costMessage, errorMessage: viewModel.publishError) { title in
                Task { await viewModel.publish(title: title) }
            }
        }
        .onChange(of: viewModel.publishedTitle) {
            if viewModel.publishedTitle != nil {
                isNaming = false
            }
        }
        .onDisappear { arSession.stopCamera() }
    }

    @ViewBuilder
    private var statusLines: some View {
        switch arSession.phase {
        case .placing:
            AuraPill(text: "Point at a wall, then tap it")
        case .mapping:
            AuraPill(text: mappingGuidance(arSession.mapping))
            AuraPill(text: "Pinch to resize. Tap again to move it.")
        case .restoring:
            AuraPill(text: "Match this view and move slowly")
        case .restored:
            AuraPill(text: "Wall restored")
        default:
            EmptyView()
        }

        if arSession.isCameraActive, let guidance = trackingGuidance(arSession.tracking) {
            AuraPill(text: guidance)
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        if let publishedTitle = viewModel.publishedTitle {
            StatusBanner(systemImage: "checkmark.circle", message: "\u{201C}\(publishedTitle)\u{201D} is live. People within 50 m can now open it from the map.")
            Button("Place another wall") { viewModel.startPlacing() }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
            Button("Done") { viewModel.finish() }
                .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
        } else {
            switch arSession.phase {
            case .idle:
                idleControls
            case .placing:
                Button("Cancel") { viewModel.finish() }
                    .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
            case .mapping:
                Button {
                    Task {
                        if await viewModel.captureWall() {
                            isNaming = true
                        }
                    }
                } label: {
                    if viewModel.isCapturing {
                        ProgressView().tint(Color.auraInk)
                    } else {
                        Text("Publish wall")
                    }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
                .disabled(!arSession.canExport || viewModel.isPublishing || viewModel.isCapturing)
                Button("Cancel") { viewModel.finish() }
                    .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
            case .restoring:
                Button("Cancel") { viewModel.finish() }
                    .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
            case .restored:
                Button("Done") { viewModel.finish() }
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
            case .failed(let message, _):
                StatusBanner(systemImage: "exclamationmark.triangle", message: message)
                Button("Back") { viewModel.finish() }
                    .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
            }
        }
    }

    @ViewBuilder
    private var idleControls: some View {
        if !isARSupported {
            StatusBanner(systemImage: "arkit", message: "This device can't run AR. Use a physical iPhone that supports ARKit.")
        } else {
            Text("Tap a wall to place it, resize it, then scan the area until it's mapped. Publishing puts it on the map at your location.")
                .font(.auraNotice)
                .foregroundStyle(.white)
                .opacity(0.75)

            Button("Place a wall") { viewModel.startPlacing() }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
        }
    }
}

// Size controls
struct WallSizeControls: View {
    let size: WallSize
    let onStep: (Int, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            Text(wallSizeText(size))
                .font(.auraCardTitle)
                .foregroundStyle(Color.auraText)
            SizeStepperRow(title: "Width", onDecrease: { onStep(-1, 0) }, onIncrease: { onStep(1, 0) })
            SizeStepperRow(title: "Height", onDecrease: { onStep(0, -1) }, onIncrease: { onStep(0, 1) })
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
    }
}

private struct SizeStepperRow: View {
    let title: String
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.auraNotice)
                .foregroundStyle(Color.auraText)
            Spacer()
            Button(action: onDecrease) {
                Image(systemName: "minus")
                    .frame(width: AuraSize.minTap, height: AuraSize.minTap)
            }
            .accessibilityLabel("Decrease \(title.lowercased())")
            Button(action: onIncrease) {
                Image(systemName: "plus")
                    .frame(width: AuraSize.minTap, height: AuraSize.minTap)
            }
            .accessibilityLabel("Increase \(title.lowercased())")
        }
        .font(.auraCardTitle)
        .foregroundStyle(Color.auraText)
    }
}
