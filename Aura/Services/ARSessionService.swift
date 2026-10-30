import Foundation
import SwiftUI
import UIKit
import ARKit
import RealityKit
import Observation

enum ARWallPhase: Equatable {
    case idle
    case placing
    case mapping
    case restoring(startedAt: Date)
    case restored
    case failed(message: String, canRetryRestore: Bool)
}

struct ExportedWall {
    let wallID: String
    let mapData: Data
    let size: WallSize
}

let wallPlaneOpacity: CGFloat = 0.55
let worldMapArchiveVersion = 1
let messageFontSizeMeters: CGFloat = 0.04
let messageCardWidthFraction = 0.4
let messageCardPaddingMeters: Float = 0.02
let messageCardCornerRadiusMeters: Float = 0.01
let messageLiftMeters: Float = 0.004
let messageTextDepthMeters: Float = 0.002

@MainActor @Observable
final class ARSessionService: NSObject, ARSessionDelegate {
    private(set) var phase: ARWallPhase = .idle
    private(set) var tracking: TrackingStatus = .notAvailable
    private(set) var mapping: MappingStatus = .notAvailable
    private(set) var wallSize = defaultWallSize
    private(set) var isCameraActive = false
    private(set) var hasPlacedWall = false

    @ObservationIgnored private var arView: ARView?
    @ObservationIgnored private var wallID: String?
    @ObservationIgnored private var placedAnchor: ARAnchor?
    @ObservationIgnored private var wallEntity: AnchorEntity?
    @ObservationIgnored private var wallPlane: ModelEntity?
    @ObservationIgnored private var wallFrameHolder: Entity?
    @ObservationIgnored private var wallFrame: Entity?
    @ObservationIgnored private var messageCanvas: Entity?
    @ObservationIgnored private var messagesToShow: [WallMessage] = []
    @ObservationIgnored private var pinchStartSize = defaultWallSize
    @ObservationIgnored private var sessionGeneration = 0

    override init() {
        super.init()
        removeLeftoverLocalCopy()
    }

    var canExport: Bool {
        phase == .mapping && canSaveWorldMap(tracking: tracking, mapping: mapping, hasWallAnchor: hasPlacedWall)
    }

    var canResize: Bool {
        phase == .placing || phase == .mapping
    }

    var currentWallID: String? { wallID }

    func arViewForDisplay() -> ARView {
        if let arView { return arView }
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        view.session.delegate = self
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:))))
        arView = view
        return view
    }

    func startPlacing() {
        removeWallEntity()
        wallID = UUID().uuidString.lowercased()
        placedAnchor = nil
        hasPlacedWall = false
        wallSize = defaultWallSize

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        run(configuration)
        phase = .placing
    }

    func resizeWall(to size: WallSize) {
        guard canResize else { return }
        wallSize = clampedWallSize(size)
        applyWallSize()
    }

    func stepWallSize(widthSteps: Int, heightSteps: Int) {
        resizeWall(to: steppedWallSize(wallSize, widthSteps: widthSteps, heightSteps: heightSteps))
    }

    // Save world map
    func exportPlacedWall() async throws -> ExportedWall {
        guard canExport, let wallID, let session = arView?.session else {
            throw WorldMapArchiveError.exportFailed
        }

        let map = try await currentWorldMap(from: session)
        guard map.anchors.contains(where: { $0.name == wallID }) else {
            throw WorldMapArchiveError.missingWallAnchor
        }
        let mapData = try encodeWorldMap(map)
        return ExportedWall(wallID: wallID, mapData: mapData, size: wallSize)
    }

    // Restore published wall
    func restoreWall(mapData: Data, wallID restoredWallID: String, size: WallSize) {
        do {
            let map = try decodeWorldMap(mapData, expectedAnchorName: restoredWallID)
            removeWallEntity()
            wallID = restoredWallID
            wallSize = clampedWallSize(size)
            placedAnchor = nil
            hasPlacedWall = false

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.vertical]
            // Restore saved map
            configuration.initialWorldMap = map
            run(configuration)

            let startedAt = Date()
            phase = .restoring(startedAt: startedAt)
            scheduleRelocalizationTimeout(startedAt: startedAt, generation: sessionGeneration)
        } catch {
            phase = .failed(message: worldMapErrorMessage(error), canRetryRestore: false)
        }
    }

    func showMessages(_ messages: [WallMessage]) {
        messagesToShow = Array(messages.prefix(maximumMessagesOnARWall))
        if phase == .restored {
            renderMessages()
        }
    }

    func stopCamera() {
        sessionGeneration += 1
        arView?.session.pause()
        isCameraActive = false
        switch phase {
        case .placing, .mapping, .restoring:
            removeWallEntity()
            phase = .idle
        default:
            break
        }
    }

    func finish() {
        stopCamera()
        removeWallEntity()
        phase = .idle
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        MainActor.assumeIsolated {
            handleFrame(frame)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            sessionGeneration += 1
            isCameraActive = false
            phase = .failed(message: worldMapErrorMessage(error), canRetryRestore: false)
        }
    }

    // Tracking status
    private func handleFrame(_ frame: ARFrame) {
        let newTracking = trackingStatus(from: frame.camera.trackingState)
        let newMapping = mappingStatus(from: frame.worldMappingStatus)
        if newTracking != tracking { tracking = newTracking }
        if newMapping != mapping { mapping = newMapping }

        guard case .restoring = phase, let wallID else { return }
        let restoredAnchor = frame.anchors.first { $0.name == wallID }
        if isWallRestored(tracking: newTracking, hasExpectedAnchor: restoredAnchor != nil), let restoredAnchor {
            showWall(on: restoredAnchor)
            phase = .restored
            renderMessages()
        }
    }

    // Tap to place
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard canResize, let arView else { return }

        let point = gesture.location(in: arView)
        // Raycast to wall
        guard let hit = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .vertical).first else { return }

        if let placedAnchor {
            arView.session.remove(anchor: placedAnchor)
        }
        let newWallID = UUID().uuidString.lowercased()
        wallID = newWallID
        let anchor = ARAnchor(name: newWallID, transform: hit.worldTransform)
        arView.session.add(anchor: anchor)
        placedAnchor = anchor
        hasPlacedWall = true
        showWall(on: anchor)
        phase = .mapping
    }

    // Pinch to resize
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard canResize, hasPlacedWall else { return }
        switch gesture.state {
        case .began:
            pinchStartSize = wallSize
        case .changed, .ended:
            resizeWall(to: resizedWallSize(start: pinchStartSize, pinchScale: Double(gesture.scale)))
        default:
            break
        }
    }

    // Run session
    private func run(_ configuration: ARWorldTrackingConfiguration) {
        sessionGeneration += 1
        tracking = .initializing
        mapping = .notAvailable
        arViewForDisplay().session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isCameraActive = true
    }

    // Relocalize timeout
    private func scheduleRelocalizationTimeout(startedAt: Date, generation: Int) {
        Task {
            try? await Task.sleep(for: .seconds(relocalizationTimeoutSeconds))
            guard generation == sessionGeneration,
                  case .restoring = phase,
                  hasRelocalizationTimedOut(startedAt: startedAt, now: Date(), timeoutSeconds: relocalizationTimeoutSeconds) else { return }
            phase = .failed(
                message: "Couldn't match this place within \(Int(relocalizationTimeoutSeconds)) seconds. Stand about 1–2 m from the wall, check the lighting is similar, and try again.",
                canRetryRestore: true
            )
        }
    }

    // Capture world map
    private func currentWorldMap(from session: ARSession) async throws -> ARWorldMap {
        try await withCheckedThrowingContinuation { continuation in
            session.getCurrentWorldMap { map, error in
                if let map {
                    continuation.resume(returning: map)
                } else {
                    continuation.resume(throwing: error ?? WorldMapArchiveError.exportFailed)
                }
            }
        }
    }

    // Draw wall plane
    private func showWall(on anchor: ARAnchor) {
        guard let arView else { return }
        removeWallEntity()

        let material = SimpleMaterial(color: UIColor(Color.auraMint).withAlphaComponent(wallPlaneOpacity), isMetallic: false)
        let plane = ModelEntity(mesh: .generatePlane(width: 1, depth: 1), materials: [material])

        let canvas = Entity()
        if canvasNeedsFlip(anchorZAxisWorldY: anchor.transform.columns.2.y) {
            canvas.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
        }

        let frameHolder = Entity()
        frameHolder.orientation = canvas.orientation

        let entity = AnchorEntity(anchor: anchor)
        entity.addChild(plane)
        entity.addChild(frameHolder)
        entity.addChild(canvas)
        arView.scene.addAnchor(entity)

        wallEntity = entity
        wallPlane = plane
        wallFrameHolder = frameHolder
        messageCanvas = canvas
        applyWallSize()

        Task { await attachFrame(to: frameHolder) }
    }

    // Brick frame model
    private func attachFrame(to holder: Entity) async {
        guard let frame = await WallModelLibrary.shared.frameEntity() else { return }
        guard wallFrameHolder === holder, holder.parent != nil else { return }
        let pivot = Entity()
        pivot.orientation = wallFrameOrientation
        pivot.addChild(frame)
        holder.addChild(pivot)
        wallFrame = pivot
        wallPlane?.removeFromParent()
        wallPlane = nil
        applyWallSize()
    }

    private func applyWallSize() {
        wallPlane?.scale = SIMD3<Float>(Float(wallSize.width), 1, Float(wallSize.height))
        if let wallFrame {
            let fit = wallFrameFit(for: wallSize)
            wallFrame.scale = fit.scale
            wallFrame.position = fit.translation
        }
    }

    // Draw messages
    private func renderMessages() {
        guard let messageCanvas else { return }
        for child in Array(messageCanvas.children) {
            child.removeFromParent()
        }
        for message in messagesToShow {
            messageCanvas.addChild(makeMessageEntity(message))
        }
    }

    private func makeMessageEntity(_ message: WallMessage) -> Entity {
        let note = message.contentType == .drawing && message.drawing != nil
            ? makeDrawingCard(message)
            : makeTextCard(message)
        note.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))

        let position = messageCanvasPosition(normalizedX: message.normalizedX, normalizedY: message.normalizedY, size: wallSize)
        note.position = SIMD3<Float>(position.x, messageLiftMeters, position.z)
        return note
    }

    private func makeDrawingCard(_ message: WallMessage) -> Entity {
        guard let drawing = message.drawing, let texture = drawingTexture(drawing) else {
            var placeholder = message
            placeholder.text = "Drawing"
            return makeTextCard(placeholder)
        }
        let note = Entity()

        let cardWidth = Float(wallSize.width * messageCardWidthFraction)
        let cardHeight = cardWidth / Float(drawingAspectRatio)
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        let card = ModelEntity(
            mesh: .generatePlane(width: cardWidth, height: cardHeight, cornerRadius: messageCardCornerRadiusMeters),
            materials: [material]
        )
        note.addChild(card)
        return note
    }

    private func drawingTexture(_ drawing: MessageDrawing) -> TextureResource? {
        guard let image = drawingCGImage(drawing, pixelWidth: AuraSize.drawingTexturePixelWidth) else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .color))
    }

    private func makeTextCard(_ message: WallMessage) -> Entity {
        let textWidth = CGFloat(wallSize.width * messageCardWidthFraction)
        let textMesh = MeshResource.generateText(
            message.text.isEmpty ? "Message" : message.text,
            extrusionDepth: messageTextDepthMeters,
            font: .systemFont(ofSize: messageFontSizeMeters, weight: .bold),
            containerFrame: CGRect(x: 0, y: 0, width: textWidth, height: CGFloat(wallSize.height)),
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )
        let textBounds = textMesh.bounds
        let textColor = message.color == .ink ? UIColor.white : UIColor(Color.auraInk)
        let text = ModelEntity(mesh: textMesh, materials: [SimpleMaterial(color: textColor, isMetallic: false)])
        text.position = SIMD3<Float>(-textBounds.center.x, -textBounds.center.y, messageLiftMeters)

        let cardMesh = MeshResource.generatePlane(
            width: textBounds.extents.x + messageCardPaddingMeters * 2,
            height: textBounds.extents.y + messageCardPaddingMeters * 2,
            cornerRadius: messageCardCornerRadiusMeters
        )
        let card = ModelEntity(mesh: cardMesh, materials: [SimpleMaterial(color: UIColor(message.color.swatchColor), isMetallic: false)])

        let note = Entity()
        note.addChild(card)
        note.addChild(text)
        return note
    }

    private func removeWallEntity() {
        if let wallEntity {
            arView?.scene.removeAnchor(wallEntity)
        }
        wallEntity = nil
        wallPlane = nil
        wallFrameHolder = nil
        wallFrame = nil
        messageCanvas = nil
    }

    // Old test copy
    private func removeLeftoverLocalCopy() {
        let folder = URL.applicationSupportDirectory.appendingPathComponent("ARSpike", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
    }
}
