import Foundation
import Observation
import FirebaseFirestore

@MainActor @Observable
final class ShopStore {
    private(set) var ownedItemIDs: Set<String> = []
    private(set) var buyingItemID: ShopItemID?
    private(set) var message: String?
    private(set) var messageIsError = false

    let userID: String
    private let economy: EconomyService
    private var listener: ListenerRegistration?
    private var pendingPurchaseIDs: [ShopItemID: String] = [:]

    init(economy: EconomyService, userID: String) {
        self.economy = economy
        self.userID = userID
    }

    func start() {
        guard listener == nil else { return }
        listener = economy.listenToInventory(userID: userID) { [weak self] owned in
            self?.ownedItemIDs = owned
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func clearMessage() {
        message = nil
    }

    func buy(_ item: ShopItem, stats: UserStats?) async {
        guard buyingItemID == nil else { return }
        guard let stats else {
            show("Your points are still loading. Try again in a moment.", isError: true)
            return
        }
        let availability = shopAvailability(for: item, stats: stats, ownedItemIDs: ownedItemIDs)
        guard availability == .available else {
            show(shopRefusalMessage(for: availability, item: item), isError: true)
            return
        }

        let purchaseID = pendingPurchaseIDs[item.id] ?? UUID().uuidString
        pendingPurchaseIDs[item.id] = purchaseID
        buyingItemID = item.id
        message = nil
        defer { buyingItemID = nil }

        do {
            switch try await economy.purchase(userID: userID, item: item, purchaseID: purchaseID) {
            case .purchased, .alreadyPurchased:
                pendingPurchaseIDs[item.id] = nil
                show(shopSuccessMessage(for: item), isError: false)
            case .refused(let reason):
                pendingPurchaseIDs[item.id] = nil
                show(reason, isError: true)
            }
        } catch {
            show("Couldn't complete the purchase. Check your connection and try again. You won't be charged twice.", isError: true)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}
