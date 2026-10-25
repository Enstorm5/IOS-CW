import SwiftUI
import ARKit

struct ARSpikeView: View {
    @State private var service = ARSessionService()

    private let isARSupported = ARWorldTrackingConfiguration.isSupported

    var body: some View {
        ZStack {
            if service.isCameraActive {
                ARWallView(service: service)
                    .ignoresSafeArea()
            } else {
                AuraNightBackground()
            }

            VStack(alignment: .leading, spacing: AuraSpacing.small) {
                HStack {
                    Text("AR test")
                        .font(.auraHeading)
                        .foregroundStyle(.white)
                    Spacer()
                    AuraPill(text: "Development: P01")
                }

                statusLines

                Spacer()

                if case .restoring = service.phase, let snapshot = service.savedSnapshot {
                    GuidancePhoto(image: snapshot)
                }

                bottomControls
            }
            .padding(AuraSpacing.screen)
        }
        .onDisappear { service.stopCamera() }
    }

    @ViewBuilder
    private var statusLines: some View {
        switch service.phase {
        case .placing:
            AuraPill(text: "Point at a wall, then tap it")
        case .mapping:
            AuraPill(text: mappingGuidance(service.mapping))
        case .restoring:
            AuraPill(text: "Match this view and move slowly")
        case .restored:
            AuraPill(text: "Wall restored")
        default:
            EmptyView()
        }

        if service.isCameraActive, let guidance = trackingGuidance(service.tracking) {
            AuraPill(text: guidance)
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        switch service.phase {
        case .idle:
            idleControls
        case .placing:
            Button("Cancel") { service.finish() }
                .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
        case .mapping:
            Button("Save wall") {
                Task { await service.saveWall() }
            }
            .buttonStyle(AuraButtonStyle(kind: .highlight))
            .disabled(!service.canSave)
            Button("Cancel") { service.finish() }
                .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
        case .saving:
            ProgressView("Saving…")
                .tint(.white)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: AuraSize.control)
        case .saved:
            if let savedWall = service.savedWall {
                StatusBanner(systemImage: "checkmark.circle", message: "Saved. Map \(formattedByteCount(savedWall.mapByteCount)). Close and reopen the app, then restore it.")
            }
            Button("Restore now") { service.restoreSavedWall() }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
            Button("Done") { service.finish() }
                .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
        case .restoring:
            Button("Cancel") { service.finish() }
                .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
        case .restored:
            Button("Done") { service.finish() }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
        case .failed(let message, let canRetryRestore):
            StatusBanner(systemImage: "exclamationmark.triangle", message: message)
            if canRetryRestore {
                Button("Try again") { service.restoreSavedWall() }
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
            }
            Button("Back") { service.finish() }
                .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
        }
    }

    @ViewBuilder
    private var idleControls: some View {
        if !isARSupported {
            StatusBanner(systemImage: "arkit", message: "This device can't run AR. Use a physical iPhone that supports ARKit.")
        } else {
            Text("Place a test wall, scan the area until it's mapped, then save. Reopen the app and restore it in the same spot.")
                .font(.auraNotice)
                .foregroundStyle(.white)
                .opacity(0.75)

            Button("Place test wall") { service.startPlacing() }
                .buttonStyle(AuraButtonStyle(kind: .highlight))

            if let savedWall = service.savedWall {
                Button("Restore saved wall") { service.restoreSavedWall() }
                    .buttonStyle(AuraButtonStyle(kind: .outline, onNight: true))
                Text("Saved \(savedWall.savedAt.formatted(date: .abbreviated, time: .shortened)) · \(formattedByteCount(savedWall.mapByteCount))")
                    .font(.auraErrorText)
                    .foregroundStyle(.white)
                    .opacity(0.75)
                Button("Delete saved wall") { service.deleteSavedWall() }
                    .font(.auraLink)
                    .foregroundStyle(.white)
                    .frame(minHeight: AuraSize.minTap)
            }
        }
    }
}

private struct GuidancePhoto: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: AuraSize.guidancePhotoWidth)
            .clipShape(.rect(cornerRadius: AuraRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AuraRadius.control)
                    .strokeBorder(.white, lineWidth: AuraSize.pinBorder)
            }
            .accessibilityLabel("Guidance photo of where the wall was saved")
    }
}
