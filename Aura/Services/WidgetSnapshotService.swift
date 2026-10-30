import Foundation
import WidgetKit

final class WidgetSnapshotService {
    private let defaults = UserDefaults(suiteName: WidgetConfig.appGroupID)

    // Share with widget
    func save(_ snapshot: WidgetSnapshot) {
        guard let defaults, let data = encodeWidgetSnapshot(snapshot) else { return }
        defaults.set(data, forKey: WidgetConfig.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Clear other accounts
    func keepOnly(accountID: String?) {
        guard let defaults else { return }
        let stored = decodeWidgetSnapshot(defaults.data(forKey: WidgetConfig.snapshotKey))
        guard stored != nil, !shouldKeepWidgetSnapshot(stored, signedInAccountID: accountID) else { return }
        defaults.removeObject(forKey: WidgetConfig.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
