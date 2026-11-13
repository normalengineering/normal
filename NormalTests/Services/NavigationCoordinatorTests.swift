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

    @Test func unblockWithoutGroupTargetsAllApps() {
        let c = NavigationCoordinator()
        let request = UnblockRequest(groupID: nil, duration: .fixed(.oneHour), keyType: .nfc)
        c.requestUnblock(request)
        #expect(c.pendingAction?.action == .unblock(request))
    }

    @Test func requestWhileSettingsIsOpenWaitsForItToClose() {
        let c = NavigationCoordinator()
        c.presentSettings()
        let request = UnblockRequest(groupID: nil, duration: .ask, keyType: .qr)

        c.requestUnblock(request)

        #expect(!c.isSettingsPresented)
        #expect(c.pendingAction == nil)
        c.settingsDidDismiss()
        #expect(c.pendingAction?.action == .unblock(request))
    }

    @Test func dismissingSettingsWithoutARequestDoesNothing() {
        let c = NavigationCoordinator()
        c.presentSettings()
        c.dismissSettings()
        c.settingsDidDismiss()
        #expect(c.pendingAction == nil)
    }
}
