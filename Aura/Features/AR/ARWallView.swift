import SwiftUI
import RealityKit

// AR view bridge
struct ARWallView: UIViewRepresentable {
    let service: ARSessionService

    func makeUIView(context: Context) -> ARView {
        service.arViewForDisplay()
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
