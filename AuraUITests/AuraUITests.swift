import XCTest

final class AuraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchSignedOutApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let alreadyHaveAccount = app.buttons["I already have an account"]
        let tabBar = app.tabBars.firstMatch
        let deadline = Date().addingTimeInterval(15)
        while !alreadyHaveAccount.exists && !tabBar.exists && Date() < deadline {
            _ = alreadyHaveAccount.waitForExistence(timeout: 1)
        }
        try XCTSkipIf(tabBar.exists, "A user is already signed in on this simulator.")
        XCTAssertTrue(alreadyHaveAccount.exists, "The welcome screen should appear when signed out.")
        return app
    }

    @MainActor
    func testWelcomeLeadsToLogIn() throws {
        let app = try launchSignedOutApp()
        app.buttons["I already have an account"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Log in"].exists)
        XCTAssertTrue(app.buttons["Forgot password?"].exists)
    }

    @MainActor
    func testLogInShowsErrorsForEmptyFields() throws {
        let app = try launchSignedOutApp()
        app.buttons["I already have an account"].tap()
        XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 5))
        app.buttons["Log in"].tap()
        XCTAssertTrue(app.staticTexts["Enter your email."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSignUpShowsErrorsForEmptyFields() throws {
        let app = try launchSignedOutApp()
        app.buttons["I already have an account"].tap()
        XCTAssertTrue(app.buttons["Create an account"].waitForExistence(timeout: 5))
        app.buttons["Create an account"].tap()
        XCTAssertTrue(app.staticTexts["Create account"].waitForExistence(timeout: 5))
        app.buttons["Sign up"].tap()
        XCTAssertTrue(app.staticTexts["Enter your email."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Choose a password."].exists)
        XCTAssertTrue(app.staticTexts["Choose a display name."].exists)
    }

    @MainActor
    func testCanSwitchBetweenLogInAndSignUp() throws {
        let app = try launchSignedOutApp()
        app.buttons["I already have an account"].tap()
        XCTAssertTrue(app.buttons["Create an account"].waitForExistence(timeout: 5))
        app.buttons["Create an account"].tap()
        XCTAssertTrue(app.buttons["I already have an account"].waitForExistence(timeout: 5))
        app.buttons["I already have an account"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 5))
    }
}
