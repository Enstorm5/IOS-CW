import Foundation
import LocalAuthentication

final class BiometricService {
    var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    var methodName: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        return lockMethodName(biometryType: context.biometryType)
    }

    func unavailableMessage() -> String? {
        var error: NSError?
        guard !LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return nil }
        let code = (error as? LAError)?.code ?? .passcodeNotSet
        if case .unavailable(let message) = biometricOutcome(forErrorCode: code) {
            return message
        }
        return "App lock isn't available on this device."
    }

    // Face ID check
    func authenticate(reason: String) async -> BiometricOutcome {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let code = (error as? LAError)?.code ?? .passcodeNotSet
            return biometricOutcome(forErrorCode: code)
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success ? .success : .failed("Couldn't unlock. Try again.")
        } catch {
            let code = (error as? LAError)?.code ?? .authenticationFailed
            return biometricOutcome(forErrorCode: code)
        }
    }
}
