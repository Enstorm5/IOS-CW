import Foundation
import LocalAuthentication

let appLockIntervalSeconds: TimeInterval = 30

enum BiometricOutcome: Equatable {
    case success
    case cancelled
    case failed(String)
    case unavailable(String)
}

func shouldRelock(enabled: Bool, backgroundedAt: Date?, now: Date, intervalSeconds: TimeInterval) -> Bool {
    guard enabled, let backgroundedAt else { return false }
    let elapsed = now.timeIntervalSince(backgroundedAt)
    return elapsed < 0 || elapsed >= intervalSeconds
}

func biometricOutcome(forErrorCode code: LAError.Code) -> BiometricOutcome {
    switch code {
    case .userCancel, .systemCancel, .appCancel:
        return .cancelled
    case .authenticationFailed:
        return .failed("That didn't match. Try again.")
    case .biometryLockout:
        return .failed("Too many attempts. Use your device passcode to unlock.")
    case .passcodeNotSet:
        return .unavailable("Set a passcode on this device to use app lock.")
    case .biometryNotAvailable, .biometryNotEnrolled:
        return .unavailable("Face ID or Touch ID isn't set up on this device.")
    default:
        return .failed("Couldn't unlock. Try again.")
    }
}

func lockMethodName(biometryType: LABiometryType) -> String {
    switch biometryType {
    case .faceID: "Face ID"
    case .touchID: "Touch ID"
    case .opticID: "Optic ID"
    default: "device passcode"
    }
}

func lockScreenMessage(outcome: BiometricOutcome?) -> String? {
    switch outcome {
    case .failed(let message), .unavailable(let message): message
    default: nil
    }
}
