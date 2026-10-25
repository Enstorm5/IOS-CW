import SwiftUI
import UIKit
import ARKit
import RealityKit

let practiceWallWidthMeters: Float = 0.6
let practiceWallHeightMeters: Float = 0.4
let practiceWallOpacity: CGFloat = 0.6

struct PracticeARView: UIViewRepresentable {
    let onPlaced: () -> Void
    let onFailed: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaced: onPlaced, onFailed: onFailed)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.session.delegate = context.coordinator

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        arView.session.run(configuration)

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .verticalPlane
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.frame = arView.bounds
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        private var practiceAnchor: AnchorEntity?
        private let onPlaced: () -> Void
        private let onFailed: () -> Void

        init(onPlaced: @escaping () -> Void, onFailed: @escaping () -> Void) {
            self.onPlaced = onPlaced
            self.onFailed = onFailed
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            let point = gesture.location(in: arView)
            guard let hit = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .vertical).first else { return }

            if let practiceAnchor {
                arView.scene.removeAnchor(practiceAnchor)
            }

            let material = SimpleMaterial(color: UIColor(Color.auraMint).withAlphaComponent(practiceWallOpacity), isMetallic: false)
            let wall = ModelEntity(mesh: .generatePlane(width: practiceWallWidthMeters, depth: practiceWallHeightMeters), materials: [material])
            let anchor = AnchorEntity(world: hit.worldTransform)
            anchor.addChild(wall)
            arView.scene.addAnchor(anchor)
            practiceAnchor = anchor
            onPlaced()
        }

        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor in
                self.onFailed()
            }
        }
    }
}
