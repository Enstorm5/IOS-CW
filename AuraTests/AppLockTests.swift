import Testing
import Foundation
import LocalAuthentication
@testable import Aura

@MainActor
struct AppLockTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func relocksOnlyAfterTheInterval() {
        #expect(!shouldRelock(enabled: true, backgroundedAt: start, now: start.addingTimeInterval(29), intervalSeconds: 30))
        #expect(shouldRelock(enabled: true, backgroundedAt: start, now: start.addingTimeInterval(30), intervalSeconds: 30))
        #expect(shouldRelock(enabled: true, backgroundedAt: start, now: start.addingTimeInterval(3_600), intervalSeconds: 30))
    }

    @Test func neverRelocksWhenOffOrNeverBackgrounded() {
        #expect(!shouldRelock(enabled: false, backgroundedAt: start, now: start.addingTimeInterval(999), intervalSeconds: 30))
        #expect(!shouldRelock(enabled: true, backgroundedAt: nil, now: start, intervalSeconds: 30))
    }

    @Test func aClockGoingBackwardsLocks() {
        #expect(shouldRelock(enabled: true, backgroundedAt: start, now: start.addingTimeInterval(-5), intervalSeconds: 30))
    }

    @Test func errorCodesMapToOutcomes() {
        #expect(biometricOutcome(forErrorCode: .userCancel) == .cancelled)
        #expect(biometricOutcome(forErrorCode: .systemCancel) == .cancelled)
        #expect(biometricOutcome(forErrorCode: .appCancel) == .cancelled)
        #expect(biometricOutcome(forErrorCode: .authenticationFailed) == .failed("That didn't match. Try again."))
        #expect(biometricOutcome(forErrorCode: .biometryLockout) == .failed("Too many attempts. Use your device passcode to unlock."))
        #expect(biometricOutcome(forErrorCode: .passcodeNotSet) == .unavailable("Set a passcode on this device to use app lock."))
        #expect(biometricOutcome(forErrorCode: .biometryNotEnrolled) == .unavailable("Face ID or Touch ID isn't set up on this device."))
        #expect(biometricOutcome(forErrorCode: .biometryNotAvailable) == .unavailable("Face ID or Touch ID isn't set up on this device."))
    }

    @Test func namesTheLockMethod() {
        #expect(lockMethodName(biometryType: .faceID) == "Face ID")
        #expect(lockMethodName(biometryType: .touchID) == "Touch ID")
        #expect(lockMethodName(biometryType: .opticID) == "Optic ID")
        #expect(lockMethodName(biometryType: .none) == "device passcode")
    }

    @Test func onlyProblemsShowOnTheLockScreen() {
        #expect(lockScreenMessage(outcome: nil) == nil)
        #expect(lockScreenMessage(outcome: .cancelled) == nil)
        #expect(lockScreenMessage(outcome: .success) == nil)
        #expect(lockScreenMessage(outcome: .failed("x")) == "x")
        #expect(lockScreenMessage(outcome: .unavailable("y")) == "y")
    }
}
