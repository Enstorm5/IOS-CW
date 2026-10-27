import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class AppLockStore {
    private(set) var isEnabled = false
    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    private(set) var message: String?
    private(set) var isCovered = false

    let biometric: BiometricService
    private var backgroundedAt: Date?

    init(biometric: BiometricService) {
        self.biometric = biometric
    }

    var methodName: String { biometric.methodName }

    func configure(enabled: Bool, lockNow: Bool) {
        isEnabled = enabled
        if !enabled {
            isLocked = false
            isCovered = false
        } else if lockNow {
            isLocked = true
        }
    }

    func scenePhaseChanged(to phase: ScenePhase, now: Date) {
        isCovered = isEnabled && phase != .active
        switch phase {
        case .background:
            if backgroundedAt == nil { backgroundedAt = now }
        case .active:
            if shouldRelock(enabled: isEnabled, backgroundedAt: backgroundedAt, now: now, intervalSeconds: appLockIntervalSeconds) {
                isLocked = true
            }
            backgroundedAt = nil
        default:
            break
        }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        message = nil
        let outcome = await biometric.authenticate(reason: "Unlock Aura")
        isAuthenticating = false

        if outcome == .success {
            isLocked = false
            isCovered = false
        } else {
            message = lockScreenMessage(outcome: outcome)
        }
    }

    func confirmIdentity(reason: String) async -> BiometricOutcome {
        await biometric.authenticate(reason: reason)
    }
}
