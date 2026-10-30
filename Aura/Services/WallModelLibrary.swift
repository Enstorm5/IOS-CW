import Foundation
import UIKit
import RealityKit

@MainActor
final class WallModelLibrary {
    static let shared = WallModelLibrary()

    private var loading: Task<Entity?, Never>?

    func frameEntity() async -> Entity? {
        if loading == nil {
            loading = Task {
                guard let url = Bundle.main.url(forResource: "wall", withExtension: "usdz") else { return nil }
                guard let model = try? await Entity(contentsOf: url) else { return nil }
                useTextureBrightness(on: model)
                return model
            }
        }
        guard let template = await loading?.value else { return nil }
        return template.clone(recursive: true)
    }

    // Ignore dark AR lighting
    private func useTextureBrightness(on entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map { material in
                guard let source = material as? PhysicallyBasedMaterial else { return material }
                var unlit = UnlitMaterial()
                unlit.color = .init(tint: .white, texture: source.baseColor.texture)
                return unlit
            }
            entity.components.set(model)
        }
        for child in entity.children {
            useTextureBrightness(on: child)
        }
    }
}
