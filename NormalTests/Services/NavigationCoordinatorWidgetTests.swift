import Foundation
@testable import Normal
import Testing

@MainActor
struct NavigationCoordinatorWidgetTests {
    private func unlockURL(groupID: UUID, durationSeconds: Int? = nil, key: String? = nil) -> URL {
        WidgetDeepLink.unlockURL(groupID: groupID, durationSeconds: durationSeconds, keyTypeRawValue: key)
    }

    @Test func handleParsesGroupDurationAndKey() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.handle(url: unlockURL(groupID: id, durationSeconds: 1800, key: "NFC"))

        #expect(c.pendingGroupAction?.groupID == id)
        #expect(c.pendingGroupAction?.action == .unlock(duration: .thirtyMinutes, keyType: .nfc))
    }

    @Test func handleAllowsMissingDurationAndKey() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.handle(url: unlockURL(groupID: id))

        #expect(c.pendingGroupAction?.groupID == id)
        #expect(c.pendingGroupAction?.action == .unlock(duration: nil, keyType: nil))
    }

    @Test func handleIgnoresUnknownDurationValue() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.handle(url: unlockURL(groupID: id, durationSeconds: 999))

        #expect(c.pendingGroupAction?.groupID == id)
        #expect(c.pendingGroupAction?.action == .unlock(duration: nil, keyType: nil),
                "999s is not a known UnblockDuration")
    }

    @Test func handleParsesBlock() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.handle(url: WidgetDeepLink.blockURL(groupID: id))

        #expect(c.pendingGroupAction?.groupID == id)
        #expect(c.pendingGroupAction?.action == .block)
    }

    @Test func requestGroupBlockSetsBlockAction() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.requestGroupBlock(groupID: id)
        #expect(c.pendingGroupAction?.action == .block)
    }

    @Test func handleRejectsWrongScheme() {
        let c = NavigationCoordinator()
        c.handle(url: URL(string: "https://unlock?group=\(UUID().uuidString)")!)
        #expect(c.pendingGroupAction == nil)
    }

    @Test func handleRejectsWrongHost() {
        let c = NavigationCoordinator()
        c.handle(url: URL(string: "normal://settings?group=\(UUID().uuidString)")!)
        #expect(c.pendingGroupAction == nil)
    }

    @Test func handleRejectsInvalidGroupID() {
        let c = NavigationCoordinator()
        c.handle(url: URL(string: "normal://unlock?group=not-a-uuid")!)
        #expect(c.pendingGroupAction == nil)
    }

    @Test func handleRejectsMissingGroup() {
        let c = NavigationCoordinator()
        c.handle(url: URL(string: "normal://unlock?duration=1800")!)
        #expect(c.pendingGroupAction == nil)
    }

    @Test func handleRejectsBlockWithoutGroup() {
        let c = NavigationCoordinator()
        c.handle(url: URL(string: "normal://block")!)
        #expect(c.pendingGroupAction == nil)
    }

    @Test func eachRequestGetsAUniqueToken() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.requestGroupUnlock(groupID: id, duration: nil, keyType: nil)
        let first = c.pendingGroupAction?.token
        c.requestGroupUnlock(groupID: id, duration: nil, keyType: nil)
        let second = c.pendingGroupAction?.token

        #expect(first != nil)
        #expect(first != second, "Repeated taps of the same widget must re-trigger the flow")
    }

    @Test func clearPendingResetsRequest() {
        let c = NavigationCoordinator()
        c.handle(url: unlockURL(groupID: UUID()))
        #expect(c.pendingGroupAction != nil)
        c.clearPendingGroupAction()
        #expect(c.pendingGroupAction == nil)
    }
}
