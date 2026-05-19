import XCTest

final class RecoveryUITests: XCTestCase {
    private let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-uiTestSkipOnboarding"] + extra
        app.launch()
        return app
    }

    private func require(_ element: XCUIElement, _ message: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
    }

    private func openEmergencyTab(_ app: XCUIApplication) {
        let settings = app.buttons["nav.settings"]
        require(settings, "Settings button should exist")
        settings.tap()
        let emergencyTab = app.tabBars.buttons["Emergency"]
        require(emergencyTab, "Settings should have an Emergency tab")
        emergencyTab.tap()
    }

    func testEmergencyUnblockRescuesNoKeyBlockedUser() {
        let app = launch(["-uiTestNoKeys", "-uiTestStartBlocked"])

        require(app.staticTexts["All Selected Apps Blocked"], "Should start blocked")
        XCTAssertEqual(
            app.switches["home.preventDeleteToggle"].value as? String, "1",
            "Start with app-deletion prevented (the locked-out state)"
        )

        openEmergencyTab(app)
        require(app.staticTexts["3 of 3 remaining"], "Three emergency unblocks to start")

        app.buttons["emergency.unblockButton"].tap()
        let confirm = app.alerts.buttons["Unblock All Apps"]
        require(confirm, "Confirmation alert should appear")
        confirm.tap()
        let ok = app.alerts.buttons["OK"]
        require(ok, "Success alert should appear")
        ok.tap()

        require(app.staticTexts["2 of 3 remaining"], "A use should be consumed")
        app.buttons["Close"].tap()

        require(app.staticTexts["No Active Blocks"], "Emergency unblock must clear all blocks")
        XCTAssertEqual(
            app.switches["home.preventDeleteToggle"].value as? String, "0",
            "Emergency unblock must re-enable app deletion (the escape hatch)"
        )
    }

    func testNoKeysUnblockAlertIsDismissibleNotBricking() {
        let app = launch(["-uiTestNoKeys", "-uiTestStartBlocked"])

        require(app.staticTexts["All Selected Apps Blocked"], "Should start blocked")
        app.buttons["home.unblockAll"].tap()

        let alert = app.alerts["No Keys Available"]
        require(alert, "No-keys unblock attempt must surface a recoverable alert")
        alert.buttons["OK"].tap()

        XCTAssertTrue(
            app.staticTexts["All Selected Apps Blocked"].waitForExistence(timeout: timeout),
            "Dismissing the alert returns to a usable screen, not a dead end"
        )
    }

    func testEmergencyUnblockDisablesAfterThreeUses() {
        let app = launch([])

        openEmergencyTab(app)
        for use in 1 ... 3 {
            let button = app.buttons["emergency.unblockButton"]
            require(button, "Emergency button available on use \(use)")
            XCTAssertTrue(button.isEnabled, "Still enabled before use \(use)")
            button.tap()
            app.alerts.buttons["Unblock All Apps"].tap()
            app.alerts.buttons["OK"].tap()
        }

        require(app.staticTexts["0 of 3 remaining"], "All uses consumed")
        XCTAssertFalse(
            app.buttons["emergency.unblockButton"].isEnabled,
            "Emergency unblock disables when exhausted"
        )
    }

    func testCannotDeleteLastKey() {
        let app = launch([])

        app.tabBars.buttons["Keys"].tap()
        let card = app.staticTexts["Test Key"].firstMatch
        require(card, "The single seeded key card should be visible")
        card.press(forDuration: 1.3)

        let delete = app.buttons["Delete"].firstMatch
        require(delete, "Context menu should offer Delete")
        delete.tap()

        require(
            app.alerts["Can't Delete Key"],
            "Deleting the last key must be blocked so unblock stays possible"
        )
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts["Test Key"].firstMatch.exists, "Key must still exist")
    }
}
