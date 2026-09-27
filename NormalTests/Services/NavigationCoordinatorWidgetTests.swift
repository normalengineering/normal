import Foundation
@testable import Normal
import Testing

@MainActor
struct NavigationCoordinatorWidgetTests {
    private func unlockURL(groupID: UUID, duration: UnlockDurationRequest = .useDefault, key: String? = nil) -> URL {
        WidgetDeepLink.unlockURL(groupID: groupID, duration: duration, keyTypeRawValue: key)
    }

    @Test func handleParsesGroupDurationAndKey() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.handle(url: unlockURL(groupID: id, duration: .fixed(.thirtyMinutes), key: "NFC"))

        #expect(c.pendingGroupAction?.groupID == id)
        #expect(c.pendingGroupAction?.action == .unlock(duration: .fixed(.thirtyMinutes), keyType: .nfc))
    }

    @Test func handleAllowsMissingDurationAndKey() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.handle(url: unlockURL(groupID: id))

        #expect(c.pendingGroupAction?.groupID == id)
        #expect(c.pendingGroupAction?.action == .unlock(duration: .useDefault, keyType: nil))
    }

    @Test func handleAcceptsCustomDurationNotInPresets() throws {
        let c = NavigationCoordinator()
        let id = UUID()
        let custom = try #require(TimedUnblockDuration(validating: 5700))
        c.handle(url: unlockURL(groupID: id, duration: .fixed(custom)))

        #expect(c.pendingGroupAction?.action == .unlock(duration: .fixed(custom), keyType: nil))
    }

    @Test func handleParsesAskEachTime() {
        let c = NavigationCoordinator()
        let id = UUID()
        c.handle(url: unlockURL(groupID: id, duration: .ask))

        #expect(c.pendingGroupAction?.action == .unlock(duration: .ask, keyType: nil))
    }

    @Test(arguments: ["999", "60", "90000", "abc"])
    func handleFallsBackToAskingForInvalidDuration(_ value: String) {
        let c = NavigationCoordinator()
        let id = UUID()
        c.handle(url: URL(string: "normal://unlock?group=\(id.uuidString)&duration=\(value)")!)

        #expect(c.pendingGroupAction?.groupID == id)
        #expect(c.pendingGroupAction?.action == .unlock(duration: .ask, keyType: nil),
                "An invalid duration shows the sheet rather than guessing")
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
        c.requestGroupUnlock(groupID: id, duration: .useDefault, keyType: nil)
        let first = c.pendingGroupAction?.token
        c.requestGroupUnlock(groupID: id, duration: .useDefault, keyType: nil)
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
