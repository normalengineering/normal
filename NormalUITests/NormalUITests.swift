import Vision
import XCTest

final class NormalUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
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

        require(app.mainTab("Keys"), "Main tab bar should be visible after skipping onboarding")
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
    func testOnboardingFinishViewFAQOpensSettingsFAQ() {
        let app = launch(["-uiTestMode"])

        let getStarted = app.buttons["onboarding.getStarted"]
        require(getStarted, "Get Started button should exist on welcome step")
        getStarted.tap()
        XCTAssertTrue(getStarted.waitForNonExistence(timeout: timeout), "Welcome card should be dismissed")

        let skipPermission = app.buttons["Skip"]
        require(skipPermission, "Permission step should offer Skip")
        skipPermission.tap()

        for _ in 0..<5 {
            let next = app.buttons["Next"]
            require(next, "Each tab walkthrough step should offer Next")
            next.tap()
        }

        require(app.staticTexts["You're All Set"], "Tab walkthrough should end on the finish card")
        let viewFAQ = app.buttons["onboarding.viewFAQ"]
        require(viewFAQ, "Finish card should offer View FAQ")
        viewFAQ.tap()

        let faqTab = app.tabBars.buttons["FAQ"]
        require(faqTab, "View FAQ should open Settings")
        XCTAssertTrue(faqTab.isSelected, "Settings should open on the FAQ tab")
        require(
            app.staticTexts["Can I prevent disabling Normal via Settings? I want to make it impossible to access blocked apps."],
            "FAQ should list the Settings bypass guide"
        )
    }

    @MainActor
    func testAddKeyViaScanCreatesKey() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding"])

        let keysTab = app.mainTab("Keys")
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

        let keysTab = app.mainTab("Keys")
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
    func testLocationPickerShowsMapAndCurrentLocationControl() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding"])

        let keysTab = app.mainTab("Keys")
        require(keysTab, "Keys tab should be reachable when onboarding is skipped")
        keysTab.tap()

        let addButton = app.buttons["keys.addButton"]
        require(addButton, "Add Key button should exist")
        addButton.tap()

        let locationSegment = app.buttons["Location"]
        require(locationSegment, "Location key type should be selectable")
        locationSegment.tap()

        let setLocation = app.buttons["key.locationButton"]
        require(setLocation, "Set Location button should appear for a location key")
        setLocation.tap()

        require(app.otherElements["locationPicker.map"], "Location picker should show the map")
        require(
            app.buttons["locationPicker.useCurrentButton"],
            "Location picker should offer a current-location control"
        )
    }

    @MainActor
    func testLocationKeyInfoClosesWithTheCloseButton() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding", "-uiTestSeedLocationKey"])
        app.mainTab("Keys").tap()
        app.buttons["keys.addButton"].tap()
        let locationSegment = app.buttons["Location"]
        require(locationSegment, "Location key type should be selectable")
        locationSegment.tap()
        app.buttons["key.locationButton"].tap()

        let map = app.otherElements["locationPicker.map"].firstMatch
        require(map, "Location picker should show the map")
        sleep(2)
        map.tap()

        let close = app.buttons["locationKeyInfo.close"]
        require(close, "Tapping a saved key's area should show its details")
        XCTAssertEqual(close.label, "Close")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: timeout), "Close should dismiss the details")
        require(map, "Closing the details should return to the map")
    }

    @MainActor
    func testCustomDomainsEditorHiddenWhenToggleOff() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding"])

        let appSelectTab = app.mainTab("App Select")
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

        let appSelectTab = app.mainTab("App Select")
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
    func testCustomDomainsEditorAddsButDoesNotRemoveWhileBlocked() {
        let app = launch([
            "-uiTestMode", "-uiTestSkipOnboarding", "-uiTestCustomDomains", "-uiTestWebsitesOnly", "-uiTestStartBlocked",
        ])
        require(app.buttons["home.unblockAll"], "The seeded website should start blocked")
        XCTAssertFalse(app.buttons["home.blockAll"].exists, "Everything selected should already be blocked")

        let appSelectTab = app.mainTab("App Select")
        require(appSelectTab, "App Select tab should be reachable")
        appSelectTab.tap()

        let link = app.buttons["appSelect.customDomainsLink"]
        require(link, "Custom Domains row should remain visible while blocked")
        link.tap()

        require(app.staticTexts["example.com"], "The blocked website should be listed")
        XCTAssertFalse(
            app.buttons["customDomains.delete.example.com"].exists,
            "Websites can't be removed while blocked"
        )

        let field = app.textFields["customDomains.field"]
        require(field, "Websites can be added while blocked")
        field.tap()
        field.typeText("reddit.com")
        app.buttons["customDomains.addButton"].tap()

        require(app.staticTexts["reddit.com"], "Added website should appear in the list")
        XCTAssertFalse(
            app.buttons["customDomains.delete.reddit.com"].exists,
            "A website added while blocked can't be removed either"
        )

        app.navigationBars.buttons.element(boundBy: 0).tap()
        require(link, "Going back should return to App Select")
        app.mainTab("Home").tap()
        require(app.buttons["home.blockAll"], "The added website stays unblocked until Block All is tapped")
    }

    @MainActor
    func testGroupKeyHiddenFromKeysTabAndVisibleInViewer() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding", "-uiTestSeedGroupKey"])

        let keysTab = app.mainTab("Keys")
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

    func testMaxDailyLimitsEmptyStateAndEditors() {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding"])

        let settings = app.buttons["nav.settings"]
        require(settings, "Settings button should exist")
        settings.tap()
        let link = app.buttons["settings.maxDailyLimitsLink"]
        require(link, "Settings should show the Max Daily Limits row")
        link.tap()
        require(app.staticTexts["No Max Daily Limits"], "Empty state should explain limits")

        let guideAdd = app.buttons["usage.emptyAddLimit"]
        require(guideAdd, "The guide should offer to add a limit")
        guideAdd.tap()
        let save = app.buttons["usage.save"]
        require(save, "Editor should open")
        XCTAssertFalse(save.isEnabled, "A limit can't be saved without apps")
        app.buttons["Cancel"].tap()

        app.swipeUp()
        let resetRow = app.buttons["usage.resetTime"]
        require(resetRow, "Reset time row should be listed")
        resetRow.tap()
        let resetSave = app.buttons["usage.resetSave"]
        require(resetSave, "Reset time page should open")
        XCTAssertFalse(resetSave.isEnabled, "An unchanged reset time can't be saved")
    }

    @MainActor
    func testFAQAnswersAreNotCutOff() throws {
        try requireFAQIsNotCutOff([])
    }

    @MainActor
    func testFAQAnswersAreNotCutOffAtLargeTextSizes() throws {
        try requireFAQIsNotCutOff(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
    }

    @MainActor
    private func requireFAQIsNotCutOff(_ extra: [String]) throws {
        let app = launch(["-uiTestMode", "-uiTestSkipOnboarding"] + extra)
        app.buttons["nav.settings"].tap()
        let faqTab = app.tabBars.buttons["FAQ"]
        require(faqTab, "Settings should have an FAQ tab")
        faqTab.tap()

        var opened = Set<String>()
        var cutOff = Set<String>()
        var previousPage: [String] = []
        for _ in 0..<300 {
            let headers = app.buttons.matching(identifier: "expandableSection").allElementsBoundByIndex
            if let next = headers.first(where: { $0.isHittable && !opened.contains($0.label) }) {
                opened.insert(next.label)
                next.tap()
                sleep(1)
                continue
            }
            let page = try visibleLines(in: app)
            cutOff.formUnion(page.filter { $0.hasSuffix("\u{2026}") || $0.hasSuffix("...") })
            if page == previousPage { break }
            previousPage = page
            app.swipeUp(velocity: .slow)
            sleep(1)
        }

        XCTAssertGreaterThan(opened.count, 10, "Every FAQ question should have been opened")
        XCTAssertEqual(cutOff, [], "FAQ text should never end in an ellipsis")
    }

    @MainActor
    private func visibleLines(in app: XCUIApplication) throws -> [String] {
        let screenshot = XCUIScreen.main.screenshot().image
        guard let image = screenshot.cgImage else { return [] }
        let scale = screenshot.scale
        let top = app.buttons["Close"].frame.maxY * scale
        let bottom = app.tabBars.firstMatch.frame.minY * scale
        guard bottom > top, let band = image.cropping(to: CGRect(x: 0, y: top, width: CGFloat(image.width), height: bottom - top)) else {
            return []
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: band).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}
