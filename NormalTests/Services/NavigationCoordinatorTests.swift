import Foundation
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

    @Test func mainUnlockRequestKeepsDurationAndKey() {
        let c = NavigationCoordinator()
        c.requestMainUnlock(duration: .fixed(.oneHour), keyType: .nfc)
        #expect(c.pendingMainUnlock?.duration == .fixed(.oneHour))
        #expect(c.pendingMainUnlock?.keyType == .nfc)
        #expect(c.pendingGroupAction == nil)
    }

    @Test func repeatedMainUnlockRequestsAreDistinct() {
        let c = NavigationCoordinator()
        c.requestMainUnlock(duration: .ask, keyType: nil)
        let first = c.pendingMainUnlock
        c.requestMainUnlock(duration: .ask, keyType: nil)
        #expect(c.pendingMainUnlock != first)
    }

    @Test func clearingMainUnlockLeavesGroupAction() {
        let c = NavigationCoordinator()
        c.requestGroupBlock(groupID: UUID())
        c.requestMainUnlock(duration: .useDefault, keyType: .qr)
        c.clearPendingMainUnlock()
        #expect(c.pendingMainUnlock == nil)
        #expect(c.pendingGroupAction != nil)
    }
}
