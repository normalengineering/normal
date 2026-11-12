@testable import Normal
import Testing

@MainActor
struct NavigationCoordinatorTests {
    @Test func startsDismissed() {
        let c = NavigationCoordinator()
        #expect(!c.isSettingsPresented)
    }

    @Test func presentSettingsFlipsToTrue() {
        let c = NavigationCoordinator()
        c.presentSettings()
        #expect(c.isSettingsPresented)
    }

    @Test func dismissSettingsFlipsToFalse() {
        let c = NavigationCoordinator()
        c.presentSettings()
        c.dismissSettings()
        #expect(!c.isSettingsPresented)
    }

    @Test func unlockWithoutGroupTargetsAllApps() {
        let c = NavigationCoordinator()
        c.requestUnlock(groupID: nil, duration: .fixed(.oneHour), keyType: .nfc)
        #expect(c.pendingAction != nil)
        #expect(c.pendingAction?.groupID == nil)
        #expect(c.pendingAction?.action == .unlock(duration: .fixed(.oneHour), keyType: .nfc))
    }
}
