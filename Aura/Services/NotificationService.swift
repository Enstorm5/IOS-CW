import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var lastScheduling: Task<Void, Never>?
    private var hasPendingOpen = false

    var onOpenQuests: (() -> Void)? {
        didSet {
            if hasPendingOpen, onOpenQuests != nil {
                hasPendingOpen = false
                onOpenQuests?()
            }
        }
    }

    override init() {
        super.init()
        center.delegate = self
    }

    func isAllowedBySystem() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func replaceQuestReminders(_ planned: [PlannedNotification]) {
        let previous = lastScheduling
        lastScheduling = Task {
            await previous?.value
            await removeQuestReminders()
            for reminder in planned {
                await schedule(reminder)
            }
        }
    }

    func cancelQuestReminders() {
        let previous = lastScheduling
        lastScheduling = Task {
            await previous?.value
            await removeQuestReminders()
        }
    }

    private func removeQuestReminders() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(questReminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func schedule(_ reminder: PlannedNotification) async {
        let interval = reminder.fireDate.timeIntervalSinceNow
        guard interval >= 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { openQuests() }
    }

    private func openQuests() {
        if let onOpenQuests {
            onOpenQuests()
        } else {
            hasPendingOpen = true
        }
    }
}
