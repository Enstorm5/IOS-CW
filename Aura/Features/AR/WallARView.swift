import SwiftUI
import Observation

@MainActor @Observable
final class WallARViewModel {
    let arSession = ARSessionService()
    let wall: Wall

    private(set) var isDownloading = false
    private(set) var downloadError: String?

    private let publisher: WallPublishService
    private var mapData: Data?

    init(wall: Wall, publisher: WallPublishService) {
        self.wall = wall
        self.publisher = publisher
    }

    func start() async {
        guard let map = wall.map else {
            downloadError = "This wall doesn't have an AR map yet."
            return
        }

        if mapData == nil {
            isDownloading = true
            downloadError = nil
            do {
                mapData = try await publisher.downloadMap(wallID: wall.id, map: map)
            } catch {
                downloadError = wallMapErrorMessage(error)
            }
            isDownloading = false
        }

        guard let mapData else { return }
        arSession.restoreWall(mapData: mapData, wallID: map.anchorName, size: map.size)
    }
}

struct WallARView: View {
    let currentUser: UserProfile
    let detailViewModel: WallDetailViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WallARViewModel
    @State private var isWriting = false

    init(wall: Wall, currentUser: UserProfile, detailViewModel: WallDetailViewModel, publisher: WallPublishService) {
        self.currentUser = currentUser
        self.detailViewModel = detailViewModel
        _viewModel = State(initialValue: WallARViewModel(wall: wall, publisher: publisher))
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
                    Text(viewModel.wall.title)
                        .font(.auraHeading)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.auraCardTitle)
                            .foregroundStyle(.white)
                            .frame(width: AuraSize.minTap, height: AuraSize.minTap)
                    }
                    .accessibilityLabel("Close")
                }

                statusLines
                Spacer()
                bottomControls
            }
            .padding(AuraSpacing.screen)
        }
        .task {
            arSession.showMessages(detailViewModel.messages)
            await viewModel.start()
        }
        .onChange(of: detailViewModel.messages) {
            arSession.showMessages(detailViewModel.messages)
        }
        .onDisappear { arSession.stopCamera() }
        .sheet(isPresented: $isWriting) {
            WriteMessageView(
                initialDraft: detailViewModel.savedDraft(),
                onPost: { text, color in
                    try await detailViewModel.post(text: text, color: color, author: currentUser)
                },
                onSaveDraft: { text, color in detailViewModel.saveDraft(text: text, color: color) },
                onDiscardDraft: { detailViewModel.discardDraft() }
            )
        }
    }

    @ViewBuilder
    private var statusLines: some View {
        if viewModel.isDownloading {
            AuraPill(text: "Downloading the wall…")
        }
        switch arSession.phase {
        case .restoring:
            AuraPill(text: "Stand 1–2 m from the wall and move slowly")
        case .restored:
            AuraPill(text: "Wall found")
        default:
            EmptyView()
        }
        if arSession.isCameraActive, let guidance = trackingGuidance(arSession.tracking) {
            AuraPill(text: guidance)
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        if let downloadError = viewModel.downloadError {
            StatusBanner(systemImage: "exclamationmark.triangle", message: downloadError)
            Button("Try again") {
                Task { await viewModel.start() }
            }
            .buttonStyle(AuraButtonStyle(kind: .highlight))
            Button("Read messages instead") { dismiss() }
                .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
        } else {
            switch arSession.phase {
            case .restored:
                Button("Write on wall") { isWriting = true }
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
            case .failed(let message, _):
                StatusBanner(systemImage: "exclamationmark.triangle", message: message)
                Button("Try again") {
                    Task { await viewModel.start() }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
                Button("Read messages instead") { dismiss() }
                    .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
            default:
                EmptyView()
            }
        }
    }
}
