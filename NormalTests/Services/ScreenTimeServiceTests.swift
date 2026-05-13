@testable import Normal
import FamilyControls
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

    // MARK: - applyShieldOnAll / removeShieldOnAll App Delete Tests

    @Test @MainActor func applyShieldOnAllWithPreventAppDeleteEnablesIt() {
        let mock = MockScreenTimeService()
        let selection = FamilyActivitySelection()

        mock.applyShieldOnAll(selection: selection, preventAppDelete: true)

        #expect(mock.applyShieldOnAllCalled)
        #expect(mock.enablePreventAppDeleteCalled)
    }

    @Test @MainActor func applyShieldOnAllWithoutPreventAppDeleteDoesNotEnableIt() {
        let mock = MockScreenTimeService()
        let selection = FamilyActivitySelection()

        mock.applyShieldOnAll(selection: selection, preventAppDelete: false)

        #expect(mock.applyShieldOnAllCalled)
        #expect(!mock.enablePreventAppDeleteCalled)
    }

    @Test @MainActor func removeShieldOnAllWithAllowAppDeleteDisablesIt() {
        let mock = MockScreenTimeService()

        mock.removeShieldOnAll(allowAppDelete: true)

        #expect(mock.removeShieldOnAllCalled)
        #expect(mock.disablePreventAppDeleteCalled)
    }

    @Test @MainActor func removeShieldOnAllWithoutAllowAppDeleteDoesNotDisableIt() {
        let mock = MockScreenTimeService()

        mock.removeShieldOnAll(allowAppDelete: false)

        #expect(mock.removeShieldOnAllCalled)
        #expect(!mock.disablePreventAppDeleteCalled)
    }
}
