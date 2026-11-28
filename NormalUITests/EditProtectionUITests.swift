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
}
