import Foundation

let minimumPasswordLength = 8
let displayNameLengthRange = 2...30

// Email check
func emailValidationError(_ email: String) -> String? {
    let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.isEmpty { return "Enter your email." }

    let parts = cleaned.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, !cleaned.contains(" ") else {
        return "That email doesn't look right."
    }
    let domain = parts[1]
    guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else {
        return "That email doesn't look right."
    }
    return nil
}

// Password check
func newPasswordValidationError(_ password: String) -> String? {
    if password.isEmpty { return "Choose a password." }
    if password.count < minimumPasswordLength {
        return "Use at least \(minimumPasswordLength) characters."
    }
    return nil
}

func logInPasswordValidationError(_ password: String) -> String? {
    password.isEmpty ? "Enter your password." : nil
}

// Name check
func displayNameValidationError(_ name: String) -> String? {
    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.isEmpty { return "Choose a display name." }
    if cleaned.count < displayNameLengthRange.lowerBound { return "Use at least \(displayNameLengthRange.lowerBound) characters." }
    if cleaned.count > displayNameLengthRange.upperBound { return "Use \(displayNameLengthRange.upperBound) characters or fewer." }
    return nil
}

func interestsValidationError(_ interests: Set<Interest>) -> String? {
    interests.isEmpty ? "Pick at least one." : nil
}
