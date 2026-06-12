import XCTest

final class DonationUITests: XCTestCase {
    private let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-uiTestSkipOnboarding"]
        app.launch()
        return app
    }

    private func require(_ element: XCUIElement, _ message: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
    }

    func testDonateButtonOpensDonationTabWithOptionalMessaging() {
        let app = launch()

        let donate = app.buttons["nav.donate"]
        require(donate, "Donation button should sit next to the settings button")
        donate.tap()

        require(app.staticTexts["Support Normal"], "Donate tab should open from the donation button")
        require(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS 'Completely optional'")
            ).firstMatch,
            "Donation copy must make clear it's completely optional"
        )

        require(app.buttons["donation.onetime.5"], "One-time $5 tier should render")
        XCTAssertTrue(app.buttons["donation.onetime.100"].exists, "All one-time tiers should render")

        app.buttons["Monthly"].tap()
        require(app.buttons["donation.monthly.5"], "Switching to Monthly should show monthly tiers")
    }
}
