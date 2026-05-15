@testable import Normal
import FamilyControls
import Testing

@MainActor
struct ScreenTimeServiceTests {
    @Test func applyShieldOnAllWithPreventAppDeleteEnablesIt() {
        let s = FakeScreenTimeService()
        s.applyShieldOnAll(selection: FamilyActivitySelection(), preventAppDelete: true)
        #expect(s.applyShieldOnAllCalled)
        #expect(s.enablePreventAppDeleteCalled)
    }

    @Test func applyShieldOnAllWithoutPreventAppDeleteDoesNotEnable() {
        let s = FakeScreenTimeService()
        s.applyShieldOnAll(selection: FamilyActivitySelection(), preventAppDelete: false)
        #expect(s.applyShieldOnAllCalled)
        #expect(!s.enablePreventAppDeleteCalled)
    }

    @Test func removeShieldOnAllWithAllowAppDeleteDisablesIt() {
        let s = FakeScreenTimeService()
        s.removeShieldOnAll(allowAppDelete: true)
        #expect(s.removeShieldOnAllCalled)
        #expect(s.disablePreventAppDeleteCalled)
    }

    @Test func removeShieldOnAllWithoutAllowAppDeleteDoesNotDisable() {
        let s = FakeScreenTimeService()
        s.removeShieldOnAll(allowAppDelete: false)
        #expect(s.removeShieldOnAllCalled)
        #expect(!s.disablePreventAppDeleteCalled)
    }

    @Test func notifyUpdateIncrementsCount() {
        let s = FakeScreenTimeService()
        s.notifyUpdate()
        s.notifyUpdate()
        #expect(s.notifyUpdateCallCount == 2)
    }

    @Test func ensureAuthorizedReturnsTrueIfAlready() async {
        let s = FakeScreenTimeService()
        s.authorizationState = .authorized
        #expect(await s.ensureAuthorized())
    }

    @Test func ensureAuthorizedRequestsAndAuthorizes() async {
        let s = FakeScreenTimeService()
        s.authorizationState = .notAuthorized
        #expect(await s.ensureAuthorized())
        #expect(s.authorizationState == .authorized)
    }
}
