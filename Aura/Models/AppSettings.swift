import Foundation

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

// Per-account settings
struct UserSettings: Equatable {
    var theme: AppTheme = .system
    var appLockEnabled = false
    var questRemindersEnabled = false
}
