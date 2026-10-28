import Foundation

let maximumStreakFreezes = 2

enum ShopItemID: String, CaseIterable, Identifiable {
    case neonBrush
    case streakFreeze

    var id: String { rawValue }
}

enum ShopItemKind {
    case permanent
    case consumable
}

struct ShopItem: Identifiable, Equatable {
    let id: ShopItemID
    let title: String
    let detail: String
    let price: Int
    let kind: ShopItemKind
    let systemImage: String
}

let shopCatalog = [
    ShopItem(
        id: .neonBrush,
        title: "Neon brush",
        detail: "A glowing brush for hand-drawn messages. Yours to keep.",
        price: 300,
        kind: .permanent,
        systemImage: "paintbrush.pointed.fill"
    ),
    ShopItem(
        id: .streakFreeze,
        title: "Streak freeze",
        detail: "Saves your streak if you miss one day. Used automatically on your next discovery. Hold up to \(maximumStreakFreezes).",
        price: 150,
        kind: .consumable,
        systemImage: "snowflake"
    ),
]

enum ShopAvailability: Equatable {
    case available
    case owned
    case notEnoughPoints(missing: Int)
    case limitReached
}

func shopAvailability(for item: ShopItem, stats: UserStats, ownedItemIDs: Set<String>) -> ShopAvailability {
    switch item.kind {
    case .permanent:
        if ownedItemIDs.contains(item.id.rawValue) { return .owned }
    case .consumable:
        if item.id == .streakFreeze && stats.streakFreezes >= maximumStreakFreezes { return .limitReached }
    }
    if !canAfford(balance: stats.balance, cost: item.price) {
        return .notEnoughPoints(missing: item.price - stats.balance)
    }
    return .available
}

func shopButtonTitle(for item: ShopItem, availability: ShopAvailability) -> String {
    switch availability {
    case .available: "Buy for \(formattedPoints(item.price))"
    case .owned: "Owned"
    case .notEnoughPoints(let missing): "Need \(formattedPoints(missing)) more"
    case .limitReached: "Holding the most"
    }
}

func shopStatusText(for item: ShopItem, stats: UserStats) -> String? {
    guard item.id == .streakFreeze else { return nil }
    return "You have \(stats.streakFreezes) of \(maximumStreakFreezes)."
}

func shopRefusalMessage(for availability: ShopAvailability, item: ShopItem) -> String {
    switch availability {
    case .available: "Couldn't complete the purchase."
    case .owned: "You already own the \(item.title)."
    case .notEnoughPoints(let missing): "You need \(formattedPoints(missing)) more for the \(item.title)."
    case .limitReached: "You already hold \(maximumStreakFreezes) streak freezes."
    }
}

func shopSuccessMessage(for item: ShopItem) -> String {
    switch item.id {
    case .neonBrush: "Neon brush unlocked. Find it when you draw a message."
    case .streakFreeze: "Streak freeze added. It protects one missed day."
    }
}

func statsAfterPurchase(_ stats: UserStats, item: ShopItem, purchaseID: String) -> UserStats {
    var updated = stats
    updated.balance -= item.price
    updated.lastPurchaseID = purchaseID
    if item.id == .streakFreeze {
        updated.streakFreezes += 1
    }
    return updated
}

func shopItem(withID id: String) -> ShopItem? {
    shopCatalog.first { $0.id.rawValue == id }
}
