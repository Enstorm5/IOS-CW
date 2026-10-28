import SwiftUI

private struct OwnedShopItemsKey: EnvironmentKey {
    static let defaultValue: Set<String> = []
}

extension EnvironmentValues {
    var ownedShopItems: Set<String> {
        get { self[OwnedShopItemsKey.self] }
        set { self[OwnedShopItemsKey.self] = newValue }
    }
}
