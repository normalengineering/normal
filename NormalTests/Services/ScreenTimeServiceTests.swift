@testable import Normal
import Testing

struct ScreenTimeServiceTests {
    @Test func blockStatusShortLabels() {
        #expect(BlockStatus.all.shortLabel == "Blocked")
        #expect(BlockStatus.some.shortLabel == "Partial")
        #expect(BlockStatus.none.shortLabel == "Unblocked")
    }

    @Test func authorizationStateCases() {
        let authorized = AuthorizationState.authorized
        let notAuthorized = AuthorizationState.notAuthorized

        // Verify both cases exist and are distinct
        if case .authorized = authorized {} else {
            Issue.record("Expected .authorized")
        }
        if case .notAuthorized = notAuthorized {} else {
            Issue.record("Expected .notAuthorized")
        }
    }
}
