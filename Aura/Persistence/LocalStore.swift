import Foundation
import CoreData

final class LocalStore {
    private let context: NSManagedObjectContext

    init(persistence: PersistenceController) {
        context = persistence.container.viewContext
    }

    func draft(accountID: String, wallID: String) -> MessageDraft? {
        guard let entity = fetchDraftEntity(key: localKey(accountID: accountID, itemID: wallID)) else { return nil }
        return messageDraft(from: entity)
    }

    func saveDraft(_ draft: MessageDraft) throws {
        let key = localKey(accountID: draft.accountID, itemID: draft.wallID)
        let entity = fetchDraftEntity(key: key) ?? MessageDraftEntity(context: context)
        entity.key = key
        entity.accountID = draft.accountID
        entity.wallID = draft.wallID
        entity.text = draft.text
        entity.colorRaw = draft.color.rawValue
        entity.updatedAt = draft.updatedAt
        try context.save()
    }

    func deleteDraft(accountID: String, wallID: String) throws {
        guard let entity = fetchDraftEntity(key: localKey(accountID: accountID, itemID: wallID)) else { return }
        context.delete(entity)
        try context.save()
    }

    func draftCount(accountID: String) -> Int {
        let request = MessageDraftEntity.fetchRequest()
        request.predicate = NSPredicate(format: "accountID == %@", accountID)
        return (try? context.count(for: request)) ?? 0
    }

    func cacheWalls(_ walls: [Wall], accountID: String, fetchedAt: Date) throws {
        for wall in walls {
            let key = localKey(accountID: accountID, itemID: wall.id)
            let request = CachedWallEntity.fetchRequest()
            request.predicate = NSPredicate(format: "key == %@", key)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? CachedWallEntity(context: context)
            entity.key = key
            entity.accountID = accountID
            entity.wallID = wall.id
            entity.title = wall.title
            entity.latitude = wall.coordinate.latitude
            entity.longitude = wall.coordinate.longitude
            entity.kindRaw = wall.kind.rawValue
            entity.mapInfoData = wall.map.flatMap { try? JSONEncoder().encode($0) }
            entity.fetchedAt = fetchedAt
        }
        try context.save()
    }

    func cachedWalls(accountID: String) -> CachedWalls {
        let request = CachedWallEntity.fetchRequest()
        request.predicate = NSPredicate(format: "accountID == %@", accountID)
        let entities = (try? context.fetch(request)) ?? []
        return CachedWalls(
            walls: entities.compactMap(wall(from:)),
            savedAt: entities.compactMap(\.fetchedAt).max()
        )
    }

    func replaceCachedMessages(_ messages: [WallMessage], wallID: String, accountID: String, fetchedAt: Date) throws {
        let oldRequest = CachedMessageEntity.fetchRequest()
        oldRequest.predicate = NSPredicate(format: "accountID == %@ AND wallID == %@", accountID, wallID)
        for old in try context.fetch(oldRequest) {
            context.delete(old)
        }

        for message in messages {
            let entity = CachedMessageEntity(context: context)
            entity.key = localKey(accountID: accountID, itemID: "\(wallID)/\(message.id)")
            entity.accountID = accountID
            entity.wallID = wallID
            entity.messageID = message.id
            entity.authorID = message.authorID
            entity.authorName = message.authorName
            entity.text = message.text
            entity.colorRaw = message.color.rawValue
            entity.sparkCount = Int64(message.sparkCount)
            entity.createdAt = message.createdAt
            entity.normalizedX = message.normalizedX
            entity.normalizedY = message.normalizedY
            entity.fetchedAt = fetchedAt
        }
        try context.save()
    }

    func cachedMessages(wallID: String, accountID: String) -> CachedMessages {
        let request = CachedMessageEntity.fetchRequest()
        request.predicate = NSPredicate(format: "accountID == %@ AND wallID == %@", accountID, wallID)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        return CachedMessages(
            messages: entities.compactMap(wallMessage(from:)),
            savedAt: entities.compactMap(\.fetchedAt).max()
        )
    }

    func deleteAccountData(accountID: String) throws {
        let predicate = NSPredicate(format: "accountID == %@", accountID)
        try deleteObjects(MessageDraftEntity.fetchRequest(), matching: predicate)
        try deleteObjects(CachedWallEntity.fetchRequest(), matching: predicate)
        try deleteObjects(CachedMessageEntity.fetchRequest(), matching: predicate)
        try context.save()
    }

    func deleteEverything() throws {
        try deleteObjects(MessageDraftEntity.fetchRequest(), matching: nil)
        try deleteObjects(CachedWallEntity.fetchRequest(), matching: nil)
        try deleteObjects(CachedMessageEntity.fetchRequest(), matching: nil)
        try context.save()
    }

    private func fetchDraftEntity(key: String) -> MessageDraftEntity? {
        let request = MessageDraftEntity.fetchRequest()
        request.predicate = NSPredicate(format: "key == %@", key)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func deleteObjects<Entity: NSManagedObject>(_ request: NSFetchRequest<Entity>, matching predicate: NSPredicate?) throws {
        request.predicate = predicate
        for object in try context.fetch(request) {
            context.delete(object)
        }
    }

    private func messageDraft(from entity: MessageDraftEntity) -> MessageDraft? {
        guard let accountID = entity.accountID,
              let wallID = entity.wallID,
              let text = entity.text,
              let updatedAt = entity.updatedAt else { return nil }
        return MessageDraft(
            accountID: accountID,
            wallID: wallID,
            text: text,
            color: MessageColor(rawValue: entity.colorRaw ?? "") ?? .magenta,
            updatedAt: updatedAt
        )
    }

    private func wall(from entity: CachedWallEntity) -> Wall? {
        guard let wallID = entity.wallID, let title = entity.title else { return nil }
        return Wall(
            id: wallID,
            title: title,
            coordinate: Coordinate(latitude: entity.latitude, longitude: entity.longitude),
            kind: WallKind(rawValue: entity.kindRaw ?? "") ?? .community,
            map: entity.mapInfoData.flatMap { try? JSONDecoder().decode(WallMapInfo.self, from: $0) }
        )
    }

    private func wallMessage(from entity: CachedMessageEntity) -> WallMessage? {
        guard let messageID = entity.messageID,
              let wallID = entity.wallID,
              let authorID = entity.authorID,
              let text = entity.text,
              let createdAt = entity.createdAt else { return nil }
        return WallMessage(
            id: messageID,
            wallID: wallID,
            authorID: authorID,
            authorName: entity.authorName ?? "Explorer",
            text: text,
            color: MessageColor(rawValue: entity.colorRaw ?? "") ?? .magenta,
            sparkCount: Int(entity.sparkCount),
            createdAt: createdAt,
            normalizedX: entity.normalizedX,
            normalizedY: entity.normalizedY
        )
    }
}

func localKey(accountID: String, itemID: String) -> String {
    "\(accountID)|\(itemID)"
}

func offlineSavedText(_ savedAt: Date?, now: Date) -> String {
    guard let savedAt else { return "You're offline." }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return "You're offline. Showing what was saved \(formatter.localizedString(for: savedAt, relativeTo: now))."
}

func signOutMessage(unsentDraftCount: Int) -> String {
    switch unsentDraftCount {
    case ...0: "Saved walls and messages on this phone are cleared when you sign out."
    case 1: "You have 1 unsent draft on this phone. Signing out deletes it."
    default: "You have \(unsentDraftCount) unsent drafts on this phone. Signing out deletes them."
    }
}
