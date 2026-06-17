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

    private func requireEnabled(_ element: XCUIElement, _ message: String) {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, message)
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

    @MainActor
    func testAddLocationKeyCreatesKey() {
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
        nameField.typeText("Office")

        let locationSegment = app.buttons["Location"]
        require(locationSegment, "Location key type should be selectable")
        locationSegment.tap()

        let setLocation = app.buttons["key.locationButton"]
        require(setLocation, "Set Location button should appear for a location key")
        setLocation.tap()

        let pickerSave = app.buttons["locationPicker.saveButton"]
        require(pickerSave, "Location picker save button should exist")
        requireEnabled(pickerSave, "Location picker save should enable once a pin is set")
        pickerSave.tap()

        require(app.staticTexts["Location Set"], "Picking a location should mark it as set")

        let save = app.buttons["key.saveButton"]
        require(save, "Save button should exist")
        requireEnabled(save, "Save should enable once a location is captured")
        save.tap()

        require(app.staticTexts["Office"], "Saved location key should appear in the keys list")
    }

    @MainActor
    func testCustomDomainsEditorHiddenWhenToggleOff() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding"])

        let appSelectTab = app.tabBars.buttons["App Select"]
        require(appSelectTab, "App Select tab should be reachable")
        appSelectTab.tap()

        XCTAssertFalse(
            app.buttons["appSelect.customDomainsLink"].waitForExistence(timeout: 3),
            "Custom Domains entry should be hidden while the setting is off"
        )
    }

    @MainActor
    func testCustomDomainsEditorAddsDomainWhenToggleOn() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding", "-uiTestCustomDomains"])

        let appSelectTab = app.tabBars.buttons["App Select"]
        require(appSelectTab, "App Select tab should be reachable")
        appSelectTab.tap()

        let link = app.buttons["appSelect.customDomainsLink"]
        require(link, "Custom Domains entry should appear when the setting is on")
        link.tap()

        let field = app.textFields["customDomains.field"]
        require(field, "Custom Domains field should appear on the editor page")
        field.tap()
        field.typeText("reddit.com")

        let addButton = app.buttons["customDomains.addButton"]
        require(addButton, "Add button should exist")
        addButton.tap()

        require(app.staticTexts["reddit.com"], "Added domain should appear in the list")
    }

    @MainActor
    func testCustomDomainsEditorIsReadOnlyWhileBlocked() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding", "-uiTestCustomDomains", "-uiTestStartBlocked"])

        let appSelectTab = app.tabBars.buttons["App Select"]
        require(appSelectTab, "App Select tab should be reachable")
        appSelectTab.tap()

        let link = app.buttons["appSelect.customDomainsLink"]
        require(link, "Custom Domains row should remain visible while blocked")
        link.tap()

        XCTAssertFalse(
            app.textFields["customDomains.field"].waitForExistence(timeout: 3),
            "Add field should be hidden while apps are blocked"
        )
        XCTAssertFalse(app.buttons["customDomains.addButton"].exists, "Add button should be hidden while blocked")
    }

    @MainActor
    func testGroupKeyHiddenFromKeysTabAndVisibleInViewer() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding", "-uiTestSeedGroupKey"])

        let keysTab = app.tabBars.buttons["Keys"]
        require(keysTab, "Keys tab should be reachable")
        keysTab.tap()

        require(app.staticTexts["Test Key"], "Global key should appear in the Keys tab")
        XCTAssertFalse(app.staticTexts["Group Key"].exists, "A group-only key must not appear in the Keys tab list")

        let groupKeysLink = app.buttons["keys.groupKeysLink"]
        require(groupKeysLink, "Group Keys row should appear when group keys exist")
        groupKeysLink.tap()

        require(app.staticTexts["Group Key"], "Group key should appear in the Group Keys viewer")
        require(app.staticTexts["Test Group"], "Viewer should show the linked group name")
    }
}
