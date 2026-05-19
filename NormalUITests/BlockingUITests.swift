import XCTest

final class BlockingUITests: XCTestCase {
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

    private func blockViaBypass(_ app: XCUIApplication) {
        app.buttons["home.blockAll"].tap()

        let bypass = app.buttons["keySelect.blockWithoutKey"]
        require(bypass, "Choose-key sheet with bypass should appear")
        bypass.tap()

        let confirm = app.alerts.buttons["Block without key"]
        require(confirm, "Bypass confirmation alert should appear")
        confirm.tap()

        require(app.staticTexts["All Selected Apps Blocked"], "Apps should be blocked after bypass")
    }

    func testBlockAllThenPermanentUnblock() {
        let app = launch()

        require(app.staticTexts["No Active Blocks"], "Starts unblocked")
        XCTAssertTrue(app.buttons["home.blockAll"].exists)

        blockViaBypass(app)
        XCTAssertTrue(app.buttons["home.unblockAll"].exists)
        XCTAssertFalse(app.buttons["home.blockAll"].exists)

        app.buttons["home.unblockAll"].tap()
        let keyRow = app.buttons["keySelect.row.QR"]
        require(keyRow, "Unblock should require choosing the registered key")
        keyRow.tap()

        let permanent = app.buttons["timedUnblock.permanent"]
        require(permanent, "Unblock duration sheet should appear after key scan")
        permanent.tap()
        app.buttons["timedUnblock.confirm"].tap()

        require(app.staticTexts["No Active Blocks"], "Apps should be unblocked again")
        XCTAssertTrue(app.buttons["home.blockAll"].waitForExistence(timeout: timeout))
    }

    func testBlockingDisablesKeysTab() {
        let app = launch()
        blockViaBypass(app)

        app.tabBars.buttons["Keys"].tap()
        require(
            app.staticTexts["Unblock all apps to manage keys."],
            "Keys tab should show the locked footer while blocked"
        )
        XCTAssertFalse(app.buttons["keys.addButton"].isEnabled, "Add Key should be disabled while blocked")
    }

    func testPreventAppDeleteReflectsBlockedState() {
        let app = launch()

        let toggle = app.switches["home.preventDeleteToggle"]
        require(toggle, "Prevent-delete toggle should be on Home")
        XCTAssertEqual(toggle.value as? String, "0", "Starts off when nothing is blocked")

        blockViaBypass(app)
        XCTAssertEqual(
            app.switches["home.preventDeleteToggle"].value as? String,
            "1",
            "Blocking with the default setting should disable app deletion"
        )
    }

    func testTimedUnblockBannerThenBlockNowReblocks() {
        let app = launch()
        blockViaBypass(app)

        app.buttons["home.unblockAll"].tap()
        app.buttons["keySelect.row.QR"].tap()

        let confirm = app.buttons["timedUnblock.confirm"]
        require(confirm, "Timed unblock sheet should appear")
        confirm.tap()

        require(app.staticTexts["Timed Unblock Active"], "Timed-unblock banner should show")
        let blockNow = app.buttons["home.blockAllNow"]
        require(blockNow, "Banner should offer Block All Now")
        blockNow.tap()

        let bypass = app.buttons["keySelect.blockWithoutKey"]
        require(bypass, "Block All Now should allow bypass")
        bypass.tap()
        app.alerts.buttons["Block without key"].tap()

        require(app.staticTexts["All Selected Apps Blocked"], "Block All Now should re-block")
        XCTAssertFalse(app.staticTexts["Timed Unblock Active"].exists, "Banner should be gone")
    }

    func testSeededScheduleAppears() {
        let app = launch(["-uiTestSeedSchedule"])

        app.tabBars.buttons["Schedules"].tap()
        require(app.staticTexts["Test Schedule"], "Seeded schedule card should render")
        XCTAssertTrue(app.switches["schedule.enabledToggle"].exists, "Schedule enable toggle should exist")
    }
}
