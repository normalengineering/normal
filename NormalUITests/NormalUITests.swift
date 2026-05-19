import XCTest

final class NormalUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func require(_ element: XCUIElement, _ message: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
    }

    @MainActor
    func testOnboardingWelcomeAppearsAndSkipReachesMainUI() {
        let app = launch(["-uiTestMode"])

        require(app.staticTexts["Welcome to Normal"], "Onboarding welcome should appear on first launch")

        let skip = app.buttons["onboarding.skip"]
        require(skip, "Welcome skip button should exist")
        skip.tap()

        require(app.tabBars.buttons["Keys"], "Main tab bar should be visible after skipping onboarding")
        XCTAssertFalse(app.staticTexts["Welcome to Normal"].exists, "Onboarding should be dismissed")
    }

    @MainActor
    func testOnboardingGetStartedAdvancesToPermissionStep() {
        let app = launch(["-uiTestMode"])

        let getStarted = app.buttons["onboarding.getStarted"]
        require(getStarted, "Get Started button should exist on welcome step")
        getStarted.tap()

        require(app.buttons["Grant Permission"], "Get Started should advance to the Screen Time permission step")
    }

    @MainActor
    func testAddKeyViaScanCreatesKey() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding"])

        let keysTab = app.tabBars.buttons["Keys"]
        require(keysTab, "Keys tab should be reachable when onboarding is skipped")
        keysTab.tap()

        let addButton = app.buttons["keys.addButton"]
        require(addButton, "Add Key button should exist")
        addButton.tap()

        let nameField = app.textFields["key.nameField"]
        require(nameField, "Key name field should appear in the new-key sheet")
        nameField.tap()
        nameField.typeText("Test Key")

        let scanButton = app.buttons["key.scanButton"]
        require(scanButton, "Scan button should exist")
        scanButton.tap()

        require(app.staticTexts["Key Linked"], "Scan should link a key via the stubbed scanner")

        let save = app.buttons["key.saveButton"]
        require(save, "Save button should exist")
        save.tap()

        require(app.staticTexts["Test Key"], "Saved key should appear in the keys list")
    }
}
