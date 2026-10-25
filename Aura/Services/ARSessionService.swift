import Foundation
import SwiftUI
import UIKit
import ARKit
import RealityKit
import Observation

enum ARSpikePhase: Equatable {
    case idle
    case placing
    case mapping
    case saving
    case saved
    case restoring(startedAt: Date)
    case restored
    case failed(message: String, canRetryRestore: Bool)
}

let spikeWallWidthMeters: Float = 1.2
let spikeWallHeightMeters: Float = 0.8
let spikeWallOpacity: CGFloat = 0.55
let worldMapArchiveVersion = 1

@MainActor @Observable
final class ARSessionService: NSObject, ARSessionDelegate {
    private(set) var phase: ARSpikePhase = .idle
    private(set) var tracking: TrackingStatus = .notAvailable
    private(set) var mapping: MappingStatus = .notAvailable
    private(set) var savedWall: SavedWallMetadata?
    private(set) var savedSnapshot: UIImage?
    private(set) var isCameraActive = false
    private(set) var hasPlacedWall = false

    @ObservationIgnored private var arView: ARView?
    @ObservationIgnored private let store: LocalWorldMapStore
    @ObservationIgnored private var wallID: String?
    @ObservationIgnored private var placedAnchor: ARAnchor?
    @ObservationIgnored private var wallEntity: AnchorEntity?
    @ObservationIgnored private var sessionGeneration = 0

    init(store: LocalWorldMapStore = LocalWorldMapStore()) {
        self.store = store
        super.init()
        refreshSavedWall()
    }

    var canSave: Bool {
        phase == .mapping && canSaveWorldMap(tracking: tracking, mapping: mapping, hasWallAnchor: hasPlacedWall)
    }

    func arViewForDisplay() -> ARView {
        if let arView { return arView }
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        view.session.delegate = self
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:))))
        arView = view
        return view
    }

    func startPlacing() {
        removeWallEntity()
        wallID = "spike-\(UUID().uuidString)"
        placedAnchor = nil
        hasPlacedWall = false

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        run(configuration)
        phase = .placing
    }

    func saveWall() async {
        guard canSave, let wallID, let session = arView?.session else { return }
        phase = .saving

        do {
            let map = try await currentWorldMap(from: session)
            guard map.anchors.contains(where: { $0.name == wallID }) else {
                throw WorldMapArchiveError.missingWallAnchor
            }
            let mapData = try encodeWorldMap(map)
            guard let pixelBuffer = session.currentFrame?.capturedImage else {
                throw WorldMapArchiveError.snapshotFailed
            }
            let snapshotData = try snapshotJPEG(from: pixelBuffer)
            let metadata = SavedWallMetadata(
                wallID: wallID,
                savedAt: Date(),
                mapByteCount: mapData.count,
                snapshotByteCount: snapshotData.count,
                osVersion: UIDevice.current.systemVersion,
                archiveVersion: worldMapArchiveVersion
            )
            try store.save(mapData: mapData, snapshotData: snapshotData, metadata: metadata)
            refreshSavedWall()
            phase = .saved
        } catch {
            phase = .failed(message: worldMapErrorMessage(error), canRetryRestore: false)
        }
    }

    func restoreSavedWall() {
        guard let metadata = savedWall else { return }

        do {
            let map = try decodeWorldMap(try store.loadMapData(), expectedAnchorName: metadata.wallID)
            removeWallEntity()
            wallID = metadata.wallID
            placedAnchor = nil
            hasPlacedWall = false

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.vertical]
            configuration.initialWorldMap = map
            run(configuration)

            let startedAt = Date()
            phase = .restoring(startedAt: startedAt)
            scheduleRelocalizationTimeout(startedAt: startedAt, generation: sessionGeneration)
        } catch {
            phase = .failed(message: worldMapErrorMessage(error), canRetryRestore: false)
        }
    }

    func stopCamera() {
        sessionGeneration += 1
        arView?.session.pause()
        isCameraActive = false
        switch phase {
        case .placing, .mapping, .saving, .restoring:
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

    func deleteSavedWall() {
        do {
            try store.delete()
            refreshSavedWall()
        } catch {
            phase = .failed(message: "Couldn't delete the saved wall. Try again.", canRetryRestore: false)
        }
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
        }
    }

    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard phase == .placing || phase == .mapping,
              let wallID,
              let arView else { return }

        let point = gesture.location(in: arView)
        guard let hit = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .vertical).first else { return }

        if let placedAnchor {
            arView.session.remove(anchor: placedAnchor)
        }
        let anchor = ARAnchor(name: wallID, transform: hit.worldTransform)
        arView.session.add(anchor: anchor)
        placedAnchor = anchor
        hasPlacedWall = true
        showWall(on: anchor)
        phase = .mapping
    }

    private func run(_ configuration: ARWorldTrackingConfiguration) {
        sessionGeneration += 1
        tracking = .initializing
        mapping = .notAvailable
        arViewForDisplay().session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isCameraActive = true
    }

    private func scheduleRelocalizationTimeout(startedAt: Date, generation: Int) {
        Task {
            try? await Task.sleep(for: .seconds(relocalizationTimeoutSeconds))
            guard generation == sessionGeneration,
                  case .restoring = phase,
                  hasRelocalizationTimedOut(startedAt: startedAt, now: Date(), timeoutSeconds: relocalizationTimeoutSeconds) else { return }
            phase = .failed(
                message: "Couldn't match this place within \(Int(relocalizationTimeoutSeconds)) seconds. Stand where the photo was taken, check the lighting is similar, and try again.",
                canRetryRestore: true
            )
        }
    }

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

    private func showWall(on anchor: ARAnchor) {
        guard let arView else { return }
        removeWallEntity()
        let material = SimpleMaterial(color: UIColor(Color.auraMint).withAlphaComponent(spikeWallOpacity), isMetallic: false)
        let plane = ModelEntity(mesh: .generatePlane(width: spikeWallWidthMeters, depth: spikeWallHeightMeters), materials: [material])
        let entity = AnchorEntity(anchor: anchor)
        entity.addChild(plane)
        arView.scene.addAnchor(entity)
        wallEntity = entity
    }

    private func removeWallEntity() {
        if let wallEntity {
            arView?.scene.removeAnchor(wallEntity)
        }
        wallEntity = nil
    }

    private func refreshSavedWall() {
        savedWall = store.loadMetadata()
        savedSnapshot = store.loadSnapshotData().flatMap { UIImage(data: $0) }
    }
}
