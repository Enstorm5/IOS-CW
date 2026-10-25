import Foundation
import CoreData

final class PersistenceController {
    static let model: NSManagedObjectModel = {
        guard let url = Bundle(for: PersistenceController.self).url(forResource: "Aura", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            return NSManagedObjectModel()
        }
        return model
    }()

    let container: NSPersistentContainer
    private(set) var loadError: Error?

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Aura", managedObjectModel: PersistenceController.model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true

        loadError = loadStores()
        if loadError != nil && !inMemory {
            resetStoreFiles()
            loadError = loadStores()
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private func loadStores() -> Error? {
        var firstError: Error?
        container.loadPersistentStores { _, error in
            if firstError == nil {
                firstError = error
            }
        }
        return firstError
    }

    private func resetStoreFiles() {
        guard let url = container.persistentStoreDescriptions.first?.url else { return }
        try? container.persistentStoreCoordinator.destroyPersistentStore(at: url, type: .sqlite)
    }
}
