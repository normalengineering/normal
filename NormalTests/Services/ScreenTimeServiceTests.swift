import FamilyControls
@testable import Normal
import Testing

@MainActor
struct ScreenTimeServiceTests {
    @Test func blockAllWithSettingOnPreventsAppDelete() {
        let s = FakeScreenTimeService()
        s.applyShieldOnAll(selection: FamilyActivitySelection(), blockAllPreventsAppDelete: true)
        #expect(s.applyShieldOnAllCalled)
        #expect(s.enablePreventAppDeleteCalled)
    }

    @Test func blockAllWithSettingOffLeavesAppDeleteUntouched() {
        let s = FakeScreenTimeService()
        s.applyShieldOnAll(selection: FamilyActivitySelection(), blockAllPreventsAppDelete: false)
        #expect(s.applyShieldOnAllCalled)
        #expect(!s.enablePreventAppDeleteCalled)
        #expect(!s.disablePreventAppDeleteCalled)
    }

    @Test func unblockAllWithSettingOnAllowsAppDelete() {
        let s = FakeScreenTimeService()
        s.removeShieldOnAll(blockAllPreventsAppDelete: true)
        #expect(s.removeShieldOnAllCalled)
        #expect(s.disablePreventAppDeleteCalled)
    }

    @Test func unblockAllWithSettingOffLeavesAppDeleteUntouched() {
        let s = FakeScreenTimeService()
        s.removeShieldOnAll(blockAllPreventsAppDelete: false)
        #expect(s.removeShieldOnAllCalled)
        #expect(!s.disablePreventAppDeleteCalled)
        #expect(!s.enablePreventAppDeleteCalled)
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
