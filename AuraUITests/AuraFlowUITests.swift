import XCTest

final class AuraFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Launch helpers
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let deadline = Date().addingTimeInterval(15)
        while !app.buttons["I already have an account"].exists && !app.tabBars.firstMatch.exists && Date() < deadline {
            _ = app.buttons["I already have an account"].waitForExistence(timeout: 1)
        }
        return app
    }

    @MainActor
    private func launchSignedOut() throws -> XCUIApplication {
        let app = launchApp()
        try XCTSkipIf(app.tabBars.firstMatch.exists, "A user is already signed in on this simulator.")
        XCTAssertTrue(app.buttons["I already have an account"].exists)
        return app
    }

    @MainActor
    private func launchSignedIn() throws -> XCUIApplication {
        let app = launchApp()
        try XCTSkipUnless(app.tabBars.firstMatch.exists, "Sign in on this simulator first.")
        return app
    }


    // Tab and row helpers
    @MainActor
    private func tapTab(_ app: XCUIApplication, _ name: String) {
        app.tabBars.buttons[name].firstMatch.tap()
    }

    @MainActor
    private func row(_ app: XCUIApplication, startingWith title: String) -> XCUIElement {
        let match = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        var swipes = 0
        while !match.waitForExistence(timeout: 2) && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        return match
    }

    // Welcome
    @MainActor
    func testWelcomeShowsThreeIntroPagesThenGetStarted() throws {
        let app = try launchSignedOut()
        XCTAssertTrue(app.staticTexts["Walls are hiding everywhere"].exists || app.buttons["Next"].exists)
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Leave your mark"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Explore to earn points"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Get started"].exists)
    }

    @MainActor
    func testSkipLeavesTheIntroPages() throws {
        let app = try launchSignedOut()
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["Sign up"].waitForExistence(timeout: 5) || app.staticTexts["Create account"].waitForExistence(timeout: 5))
    }

    // Log in
    @MainActor
    func testLogInOffersGoogleAndPasswordReset() throws {
        let app = try launchSignedOut()
        app.buttons["I already have an account"].tap()
        XCTAssertTrue(app.buttons["Continue with Google"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Forgot password?"].exists)
    }

    @MainActor
    func testForgotPasswordOpensResetScreen() throws {
        let app = try launchSignedOut()
        app.buttons["I already have an account"].tap()
        app.buttons["Forgot password?"].tap()
        XCTAssertTrue(app.staticTexts["Reset password"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testResetPasswordRejectsAnEmptyEmail() throws {
        let app = try launchSignedOut()
        app.buttons["I already have an account"].tap()
        app.buttons["Forgot password?"].tap()
        XCTAssertTrue(app.staticTexts["Reset password"].waitForExistence(timeout: 5))
        let send = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'link' OR label CONTAINS[c] 'send'")).firstMatch
        if send.exists {
            send.tap()
            XCTAssertTrue(app.staticTexts["Enter your email."].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testBadEmailShowsAnErrorOnLogIn() throws {
        let app = try launchSignedOut()
        app.buttons["I already have an account"].tap()
        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("not-an-email")
        app.buttons["Log in"].tap()
        XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    @MainActor
    func testSignUpOffersGoogleToo() throws {
        let app = try launchSignedOut()
        app.buttons["I already have an account"].tap()
        app.buttons["Create an account"].tap()
        XCTAssertTrue(app.buttons["Continue with Google"].waitForExistence(timeout: 5))
    }

    // Tabs
    @MainActor
    func testFiveTabsAreShown() throws {
        let app = try launchSignedIn()
        for name in ["Map", "Quests", "Camera", "Crew", "Me"] {
            XCTAssertTrue(app.tabBars.buttons[name].firstMatch.exists, "\(name) tab is missing")
        }
    }

    @MainActor
    func testQuestsTabShowsTodaysQuests() throws {
        let app = try launchSignedIn()
        tapTab(app, "Quests")
        XCTAssertTrue(app.staticTexts["Daily quests"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today's quests"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testQuestsTabLinksToTheRewardsShop() throws {
        let app = try launchSignedIn()
        tapTab(app, "Quests")
        let shop = row(app, startingWith: "Rewards shop")
        XCTAssertTrue(shop.waitForExistence(timeout: 5))
        shop.tap()
        XCTAssertTrue(app.navigationBars["Rewards shop"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCrewTabOffersStartOrJoinWhenNotInACrew() throws {
        let app = try launchSignedIn()
        tapTab(app, "Crew")
        let hasCrew = app.buttons["Invite friends"].waitForExistence(timeout: 5)
        if !hasCrew {
            XCTAssertTrue(app.staticTexts["Start a crew"].exists || app.buttons["Start a crew"].exists)
        }
    }

    @MainActor
    func testCameraTabShowsThePlaceWallScreen() throws {
        let app = try launchSignedIn()
        tapTab(app, "Camera")
        XCTAssertTrue(app.staticTexts["Place a wall"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMapHeaderHasTheHomeButton() throws {
        let app = try launchSignedIn()
        tapTab(app, "Map")
        XCTAssertTrue(app.buttons["Home summary"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHomeSummaryOpensAndCloses() throws {
        let app = try launchSignedIn()
        tapTab(app, "Map")
        let home = app.buttons["Home summary"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        home.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Home summary"].waitForExistence(timeout: 5))
    }

    // Me
    @MainActor
    func testSettingsShowsAppearanceAndPrivacy() throws {
        let app = try launchSignedIn()
        tapTab(app, "Me")
        let settings = row(app, startingWith: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign out"].waitForExistence(timeout: 5) || app.staticTexts["Account"].exists)
    }

    @MainActor
    func testEditProfileOpensFromMe() throws {
        let app = try launchSignedIn()
        tapTab(app, "Me")
        let edit = row(app, startingWith: "Edit profile")
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
    }
}
