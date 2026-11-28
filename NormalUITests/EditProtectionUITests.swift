import XCTest

final class EditProtectionUITests: XCTestCase {
    private let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-uiTestSkipOnboarding"] + extra
        app.launch()
        return app
    }

    private func require(_ element: XCUIElement, _ message: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
    }

    func testEditingRequiresKeyByDefaultAndKeepsAppsBlocked() {
        let app = launch(["-uiTestStartBlocked", "-uiTestSeedSchedule"])

        app.mainTab("Schedules").tap()
        require(app.buttons["editProtection.unblockButton"], "Schedules should offer key-based edit unblock")
        XCTAssertFalse(app.switches["schedule.enabledToggle"].isEnabled, "Schedule toggle should be blocked before key check")

        app.buttons["editProtection.unblockButton"].tap()
        let keyRow = app.buttons["keySelect.row.QR"]
        require(keyRow, "Unblocking editing should prompt for a global key")
        XCTAssertFalse(app.buttons["keySelect.blockWithoutKey"].exists, "Unblocking editing must not offer a bypass")
        keyRow.tap()

        let confirm = app.buttons["timedUnblock.confirm"]
        require(confirm, "Unblocking editing should present duration choices when no default is set")
        confirm.tap()

        require(app.buttons["editProtection.blockButton"], "Active edit session should show Block Now")
        XCTAssertTrue(app.switches["schedule.enabledToggle"].isEnabled, "Schedule toggle should unblock during edit session")

        app.mainTab("Home").tap()
        require(app.staticTexts["All Selected Apps Blocked"], "Blocked apps must stay blocked during an edit session")

        app.mainTab("Schedules").tap()
        app.buttons["editProtection.blockButton"].tap()
        require(app.buttons["editProtection.unblockButton"], "Tapping Block Now should immediately re-block editing")
        XCTAssertFalse(app.switches["schedule.enabledToggle"].isEnabled, "Schedule toggle should be blocked again")
    }

    func testEditProtectionDefaultDurationSkipsDurationSheet() {
        let app = launch()

        app.buttons["nav.settings"].tap()
        let link = app.buttons["settings.editProtectionLink"]
        require(link, "General settings should have an Edit Protection drill-down")
        link.tap()

        let durationPicker = app.buttons["editProtection.defaultDuration"]
        require(durationPicker, "Edit Protection should offer a Default Duration override")
        durationPicker.tap()
        let fourHours = app.buttons["4 hours"]
        require(fourHours, "Default Duration menu should list saved unblock durations")
        fourHours.tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        require(app.buttons["Close"], "Returning to General settings should show Close")
        app.buttons["Close"].tap()

        app.mainTab("Keys").tap()
        let unblockButton = app.buttons["editProtection.unblockButton"]
        require(unblockButton, "Keys tab should require unblocking editing by default")
        unblockButton.tap()

        let keyRow = app.buttons["keySelect.row.QR"]
        require(keyRow, "Unblocking editing should prompt for a key")
        keyRow.tap()

        require(app.buttons["editProtection.blockButton"], "Default duration should start the edit session directly")
        XCTAssertFalse(app.buttons["timedUnblock.confirm"].exists, "Default duration should skip the duration sheet")
        XCTAssertTrue(app.buttons["keys.addButton"].isEnabled, "Add Key should be enabled while editing is unblocked")
    }

    func testDowngradingEditProtectionToUnblockAllRequiresKey() {
        let app = launch()

        app.buttons["nav.settings"].tap()
        let link = app.buttons["settings.editProtectionLink"]
        require(link, "General settings should have an Edit Protection drill-down")
        link.tap()

        let unblockAllRow = app.buttons["settings.editProtection.unblockAll"]
        require(unblockAllRow, "Edit Protection should list When All Apps Unblocked")
        unblockAllRow.tap()

        let keyRow = app.buttons["keySelect.row.QR"]
        require(keyRow, "Downgrading edit protection must require a global key")
        XCTAssertFalse(app.buttons["keySelect.blockWithoutKey"].exists, "Downgrading must not offer a bypass")
        keyRow.tap()

        XCTAssertTrue(
            app.buttons["editProtection.defaultDuration"].waitForNonExistence(timeout: timeout),
            "Switching to When All Apps Unblocked should hide key unblocking defaults"
        )
        app.navigationBars.buttons.element(boundBy: 0).tap()
        require(app.buttons["Close"], "Returning to General settings should show Close")
        app.buttons["Close"].tap()

        app.mainTab("Keys").tap()
        XCTAssertTrue(app.buttons["keys.addButton"].isEnabled, "Editing should now be open while no apps are blocked")
    }

    func testEmergencyUnblockOpensEditingForLostKeyRecovery() {
        let app = launch(["-uiTestStartBlocked"])

        app.buttons["nav.settings"].tap()
        let emergencyTab = app.tabBars.buttons["Emergency"]
        require(emergencyTab, "Settings should have an Emergency tab")
        emergencyTab.tap()

        app.buttons["emergency.unblockButton"].tap()
        app.alerts.buttons["Unblock All Apps"].tap()
        app.alerts.buttons["OK"].tap()
        app.buttons["Close"].tap()

        require(app.buttons["editProtection.blockButton"], "Home should show the active edit session after emergency unblock")
        app.mainTab("Keys").tap()
        require(app.buttons["editProtection.blockButton"], "Emergency unblock should grant an active edit session")
        XCTAssertTrue(app.buttons["keys.addButton"].isEnabled, "User should be able to add a replacement key after emergency unblock")
    }

    func testUnblockingEditingInsideGroupSheetAllowsNestedSheetsAndReblocksLive() {
        let app = launch(["-uiTestStartBlocked", "-uiTestSeedGroupKey"])
        app.mainTab("Groups").tap()

        let group = app.staticTexts["Test Group"]
        require(group, "Seeded group should render")
        group.tap()

        require(app.buttons["Done"], "Blocked group sheet should open read-only")
        XCTAssertFalse(app.buttons["Update"].exists, "Read-only group sheet should not show Update")
        XCTAssertFalse(app.buttons["Delete Group"].exists, "Read-only group sheet should not show Delete Group")

        let unblockButton = hittableButton(in: app, identifier: "editProtection.unblockButton")
        require(unblockButton, "Group sheet should show Unblock Editing bar")
        unblockButton.tap()

        let keyRow = app.buttons["keySelect.row.QR"]
        require(keyRow, "Unblocking editing from inside a sheet should prompt for a global key")
        XCTAssertFalse(app.buttons["keySelect.blockWithoutKey"].exists, "Unblocking editing must not offer bypass")
        keyRow.tap()

        let confirm = app.buttons["timedUnblock.confirm"]
        require(confirm, "Duration sheet should present cleanly over the group sheet")
        confirm.tap()

        require(app.buttons["Update"], "Group sheet should flip live to editable after unblocking editing")
        let selectApps = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Select Apps'")).firstMatch
        require(selectApps, "Editable group sheet should show Select Apps")
        selectApps.tap()

        let selectAppsNav = app.navigationBars["Select Apps"]
        require(selectAppsNav, "Select Apps sheet should present cleanly after edit-protection auth")
        selectAppsNav.buttons["Cancel"].tap()

        let blockNow = hittableButton(in: app, identifier: "editProtection.blockButton")
        require(blockNow, "Active edit session bar should stay visible inside the group sheet")
        blockNow.tap()

        require(app.buttons["Done"], "Tapping Block Now should return the open group sheet to read-only")
        XCTAssertFalse(app.buttons["Update"].exists, "Update button should disappear when re-blocked")
        app.buttons["Done"].tap()

        require(app.buttons["group.unblockButton"], "Blocked group must remain blocked after editing session")
    }

    func testTurningOffCustomWebsitesRequiresKeyAndSnapsBackOnCancel() {
        let app = launch(["-uiTestCustomDomains", "-uiTestStartBlocked"])

        app.buttons["nav.settings"].tap()
        let toggle = app.switches["Enable Custom Websites"]
        for _ in 0..<4 where !toggle.exists || !toggle.isHittable { app.swipeUp() }
        require(toggle, "Settings should show Enable Custom Websites")
        XCTAssertTrue(toggle.isHittable, "Enable Custom Websites should be scrolled into view")
        XCTAssertEqual(toggle.value as? String, "1", "Toggle should start enabled")

        tapSwitch(toggle)
        let keyRow = app.buttons["keySelect.row.QR"]
        require(keyRow, "Turning off custom websites should require a global key")
        XCTAssertFalse(app.buttons["keySelect.blockWithoutKey"].exists, "Turning off custom websites must not offer bypass")

        app.navigationBars.buttons["Cancel"].tap()
        requireValue("1", of: toggle, "Cancelling the key prompt should keep Enable Custom Websites on")

        tapSwitch(toggle)
        require(keyRow, "Second attempt should prompt for a key again")
        keyRow.tap()
        requireValue("0", of: toggle, "Verifying a key should turn Enable Custom Websites off")

        app.buttons["Close"].tap()
        app.mainTab("App Select").tap()
        XCTAssertFalse(
            app.buttons["appSelect.customDomainsLink"].waitForExistence(timeout: 3),
            "Custom Domains link should disappear after disabling custom websites"
        )
    }

    func testGroupKeyOnlyBlockedUserKeepsGroupKeysReachableAndDisablesAddKey() {
        let app = launch(["-uiTestNoKeys", "-uiTestSeedGroupKey", "-uiTestStartBlocked"])

        app.mainTab("Keys").tap()
        require(
            app.staticTexts["Unblock all apps to add or delete keys."],
            "Group-key-only user should see unblock-all footer while shielded"
        )
        XCTAssertFalse(app.buttons["editProtection.unblockButton"].exists, "Must not offer key edit unblock without a global key")
        XCTAssertFalse(app.buttons["keys.addButton"].isEnabled, "Toolbar Add Key must be disabled while blocked")

        let emptyAddButtons = app.buttons.matching(NSPredicate(format: "label == 'Add Key'"))
        for index in 0..<emptyAddButtons.count {
            XCTAssertFalse(emptyAddButtons.element(boundBy: index).isEnabled, "Every Add Key control must be disabled while blocked")
        }

        let groupKeysLink = app.buttons["keys.groupKeysLink"]
        require(groupKeysLink, "Group Keys link should stay reachable while blocked")
        groupKeysLink.tap()
        require(app.staticTexts["Group Key"], "Group Keys sheet should display existing group keys")
        app.buttons["Done"].tap()

        app.mainTab("App Select").tap()
        require(
            app.staticTexts["Unblock all apps to edit selection."],
            "App Select footer should match unblock-all mode when no global key exists"
        )
    }

    func testEditProtectionDefaultKeyOverrideSkipsKeyPickerAndRespectsNoneOverride() {
        let app = launch(["-uiTestSeedLocationKey"])

        app.buttons["nav.settings"].tap()
        let link = app.buttons["settings.editProtectionLink"]
        require(link, "General settings should have an Edit Protection drill-down")
        link.tap()

        let keyPicker = app.buttons["editProtection.defaultKey"]
        require(keyPicker, "Edit Protection should offer a Default Key override")
        keyPicker.tap()
        let locationOption = app.buttons["Location"]
        require(locationOption, "Default Key menu should list registered global key types")
        locationOption.tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        require(app.buttons["Close"], "Returning to General settings should show Close")
        app.buttons["Close"].tap()

        app.mainTab("Keys").tap()
        app.buttons["editProtection.unblockButton"].tap()
        let confirm = app.buttons["timedUnblock.confirm"]
        require(confirm, "Edit Default Key should skip the key picker and go straight to duration choices")
        XCTAssertFalse(app.buttons["keySelect.row.QR"].exists, "Key picker should be skipped")
        app.navigationBars.buttons["Cancel"].tap()

        app.buttons["nav.settings"].tap()
        require(link, "Settings should show Edit Protection link")
        link.tap()
        require(keyPicker, "Edit Protection should show Default Key picker")
        keyPicker.tap()
        let noneOption = app.buttons["None"]
        require(noneOption, "Default Key menu should offer None")
        noneOption.tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        require(app.buttons["Close"], "Returning to General settings should show Close")
        app.buttons["Close"].tap()

        app.buttons["editProtection.unblockButton"].tap()
        require(app.buttons["keySelect.row.QR"], "None override should restore the key picker with QR")
        require(app.buttons["keySelect.row.LOCATION"], "None override should restore the key picker with Location")
    }

    func testEditProtectionBarAndSettingsStayUsableAtLargestTextSize() {
        let app = launch([
            "-uiTestStartBlocked", "-uiTestSeedSchedule",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])

        app.mainTab("Schedules").tap()
        let unblockButton = app.buttons["editProtection.unblockButton"]
        require(unblockButton, "Blocked bar should render at XXXL")
        XCTAssertTrue(unblockButton.isHittable, "Unblock Editing button must stay hittable at XXXL")
        unblockButton.tap()

        let keyRow = app.buttons["keySelect.row.QR"]
        require(keyRow, "Key picker should appear at XXXL")
        keyRow.tap()

        let confirm = app.buttons["timedUnblock.confirm"]
        require(confirm, "Duration sheet confirm should appear at XXXL")
        for _ in 0..<4 where !confirm.isHittable { app.swipeUp() }
        XCTAssertTrue(confirm.isHittable, "Duration confirm should be reachable at XXXL")
        confirm.tap()

        let blockNow = app.buttons["editProtection.blockButton"]
        require(blockNow, "Active edit session bar should render at XXXL")
        XCTAssertTrue(blockNow.isHittable, "Block Now button must stay hittable at XXXL")

        app.buttons["nav.settings"].tap()
        let link = app.buttons["settings.editProtectionLink"]
        for _ in 0..<4 where !link.exists || !link.isHittable { app.swipeUp() }
        require(link, "Edit Protection link should be reachable at XXXL")
        link.tap()

        let durationPicker = app.buttons["editProtection.defaultDuration"]
        for _ in 0..<4 where !durationPicker.exists || !durationPicker.isHittable { app.swipeUp() }
        require(durationPicker, "Default Duration picker should be reachable at XXXL")
        durationPicker.tap()

        let fourHours = app.buttons["4 hours"]
        for _ in 0..<4 where !fourHours.exists || !fourHours.isHittable { app.swipeUp() }
        require(fourHours, "Navigation-link duration list should show 4 hours at XXXL")
        fourHours.tap()
    }

    private func hittableButton(in app: XCUIApplication, identifier: String) -> XCUIElement {
        let query = app.buttons.matching(identifier: identifier)
        _ = query.firstMatch.waitForExistence(timeout: timeout)
        for index in (0..<query.count).reversed() {
            let candidate = query.element(boundBy: index)
            if candidate.isHittable {
                return candidate
            }
        }
        return query.firstMatch
    }

    private func tapSwitch(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    private func requireValue(_ value: String, of element: XCUIElement, _ message: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, message)
    }
}
