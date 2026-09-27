import XCTest

final class UnblockDurationsUITests: XCTestCase {
    private let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
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

    private func row(_ app: XCUIApplication, seconds: Int) -> XCUIElement {
        app.descendants(matching: .any)["unblockDurations.row.\(seconds)"].firstMatch
    }

    private func openDurations(_ app: XCUIApplication) {
        let settings = app.buttons["nav.settings"]
        require(settings, "Settings button should exist")
        settings.tap()

        let link = app.buttons["settings.unblockDurationsLink"]
        require(link, "General settings should link to Unblock Durations")
        link.tap()
        require(app.navigationBars["Unblock Durations"], "Durations screen should open")
    }

    private func closeSettings(_ app: XCUIApplication) {
        app.navigationBars["Unblock Durations"].buttons.element(boundBy: 0).tap()
        let close = app.buttons["Close"]
        require(close, "Settings should offer Close")
        close.tap()
    }

    private func blockViaBypass(_ app: XCUIApplication) {
        app.buttons["home.blockAll"].tap()
        let bypass = app.buttons["keySelect.blockWithoutKey"]
        require(bypass, "Choose-key sheet with bypass should appear")
        bypass.tap()
        let confirm = app.buttons["keySelect.confirmBlockWithoutKey"]
        require(confirm, "Bypass confirmation should appear")
        confirm.tap()
        require(app.staticTexts["All Selected Apps Blocked"], "Apps should be blocked after bypass")
    }

    private func delete(_ element: XCUIElement, in app: XCUIApplication) {
        element.swipeLeft()
        let delete = app.buttons["Delete"]
        require(delete, "Swipe should reveal Delete")
        delete.tap()
    }

    func testAddedDurationIsListedSortedAndOfferedWhenUnblocking() {
        let app = launch()
        openDurations(app)
        XCTAssertTrue(row(app, seconds: 900).exists, "Presets are listed by default")

        app.buttons["unblockDurations.addButton"].tap()
        let wheels = app.pickerWheels
        require(wheels.element(boundBy: 0), "Add sheet should show the hour wheel")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "1")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "35")
        app.buttons["durationPicker.addButton"].tap()

        let added = row(app, seconds: 5700)
        require(added, "New duration should be listed")
        XCTAssertLessThan(row(app, seconds: 3600).frame.minY, added.frame.minY, "1h sorts above 1h 35m")
        XCTAssertLessThan(added.frame.minY, row(app, seconds: 14400).frame.minY, "1h 35m sorts above 4h")

        closeSettings(app)
        blockViaBypass(app)
        app.buttons["home.unblockAll"].tap()
        app.buttons["keySelect.row.QR"].tap()

        require(app.buttons["timedUnblock.duration.5700"], "Custom duration should be offered when unblocking")
    }

    func testDeletingDefaultAsksThenClearsDefault() {
        let app = launch(["-uiTestDefaultDuration", "3600"])
        openDurations(app)

        let defaultRow = row(app, seconds: 3600)
        require(defaultRow, "Default duration should be listed")
        XCTAssertTrue(app.staticTexts["Default"].exists, "Default duration should be tagged")

        delete(defaultRow, in: app)
        let alert = app.alerts["Delete Default Duration?"]
        require(alert, "Deleting the default should ask first")
        alert.buttons["Delete"].tap()

        XCTAssertFalse(row(app, seconds: 3600).waitForExistence(timeout: 2), "Row should be removed")
        XCTAssertFalse(app.staticTexts["Default"].exists, "No duration is the default anymore")
    }

    func testLastDurationCannotBeDeleted() {
        let app = launch(["-uiTestUnblockDurations", "1800"])
        openDurations(app)

        let only = row(app, seconds: 1800)
        require(only, "Seeded duration should be listed")
        delete(only, in: app)

        let alert = app.alerts["Can't Delete Duration"]
        require(alert, "Deleting the last duration should explain why it can't")
        alert.buttons["OK"].tap()
        XCTAssertTrue(row(app, seconds: 1800).exists, "Last duration stays")
    }

    func testDefaultDurationSkipsTheSheet() {
        let app = launch(["-uiTestUnblockDurations", "900,5700", "-uiTestDefaultDuration", "5700"])
        blockViaBypass(app)

        app.buttons["home.unblockAll"].tap()
        app.buttons["keySelect.row.QR"].tap()

        require(app.staticTexts["Timed Unblock Active"], "Default duration should start without the sheet")
        XCTAssertFalse(app.buttons["timedUnblock.confirm"].exists)
    }
}
