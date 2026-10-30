import Foundation
import RealityKit

// Wall model loader
@MainActor
final class WallModelLibrary {
    static let shared = WallModelLibrary()

    private var loading: Task<Entity?, Never>?

    func frameEntity() async -> Entity? {
        if loading == nil {
            loading = Task {
                guard let url = Bundle.main.url(forResource: "wall", withExtension: "usdz") else { return nil }
                return try? await Entity(contentsOf: url)
            }
        }
        guard let template = await loading?.value else { return nil }
        return template.clone(recursive: true)
    }
}
