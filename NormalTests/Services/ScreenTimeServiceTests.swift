import FamilyControls
import Foundation
@testable import Normal
import Testing

@MainActor
struct ScreenTimeServiceTests {
    private func makeService() -> (ScreenTimeService, InMemoryShieldStore) {
        let shields = InMemoryShieldStore(startBlocked: false)
        let service = ScreenTimeService(
            defaults: UserDefaults(suiteName: "screen-time-\(UUID().uuidString)")!,
            shield: shields,
            sharedStore: FakeSharedStore(),
            activityCenter: FakeDeviceActivityCenter()
        )
        return (service, shields)
    }

    @Test func blockAllWithSettingOnPreventsAppDelete() {
        let (service, shields) = makeService()
        service.blockAll(selection: TokenFixtures.selection(apps: [1]), blockAllPreventsAppDelete: true)
        #expect(shields.currentShields().applications == [TokenFixtures.app(1)])
        #expect(service.isAppDeleteDisabled)
    }

    @Test func blockAllWithSettingOffLeavesAppDeleteUntouched() {
        let (service, shields) = makeService()
        service.enablePreventAppDelete()
        service.blockAll(selection: TokenFixtures.selection(apps: [1]), blockAllPreventsAppDelete: false)
        #expect(shields.currentShields().applications == [TokenFixtures.app(1)])
        #expect(service.isAppDeleteDisabled)
    }

    @Test func unblockAllWithSettingOnAllowsAppDelete() {
        let (service, shields) = makeService()
        service.blockAll(selection: TokenFixtures.selection(apps: [1]), blockAllPreventsAppDelete: true)
        service.unblockAll(blockAllPreventsAppDelete: true)
        #expect(shields.currentShields().applications.isEmpty)
        #expect(!service.isAppDeleteDisabled)
    }

    @Test func unblockAllWithSettingOffLeavesAppDeleteUntouched() {
        let (service, shields) = makeService()
        service.blockAll(selection: TokenFixtures.selection(apps: [1]), blockAllPreventsAppDelete: true)
        service.unblockAll(blockAllPreventsAppDelete: false)
        #expect(shields.currentShields().applications.isEmpty)
        #expect(service.isAppDeleteDisabled)
    }

    @Test func adultContentFilterFollowsTheSetting() {
        let (service, shields) = makeService()
        service.setAdultContentBlocked(true)
        #expect(shields.currentShields().blocksAdultContent)
        #expect(service.isAdultContentBlocked)
        service.setAdultContentBlocked(false)
        #expect(!shields.currentShields().blocksAdultContent)
        #expect(!service.isAdultContentBlocked)
    }

    @Test func adultContentFilterIsIndependentOfBlockAll() {
        let (service, shields) = makeService()
        service.setAdultContentBlocked(true)
        #expect(service.activeShieldCount() == 0)

        service.blockAll(selection: TokenFixtures.selection(apps: [1]), blockAllPreventsAppDelete: true)
        service.unblockAll(blockAllPreventsAppDelete: true)

        #expect(shields.currentShields().blocksAdultContent)
        #expect(service.activeShieldCount() == 0)
    }

    @Test func removeAllRestrictionsLiftsAdultContentFilter() {
        let (service, shields) = makeService()
        service.setAdultContentBlocked(true)
        service.blockAll(selection: TokenFixtures.selection(apps: [1]), blockAllPreventsAppDelete: true)

        service.removeAllRestrictions()
        service.reconcile()

        #expect(shields.currentShields().applications.isEmpty)
        #expect(!service.isAppDeleteDisabled)
        #expect(!shields.currentShields().blocksAdultContent)
    }

    @Test func hidingBlockedAppsFollowsTheBlockedApps() {
        let (service, shields) = makeService()
        service.setHidingBlockedApps(true)
        #expect(service.isHidingBlockedApps)
        #expect(shields.currentShields().hiddenApplications.isEmpty)

        service.blockAll(selection: TokenFixtures.selection(apps: [1, 2]), blockAllPreventsAppDelete: false)
        #expect(shields.currentShields().hiddenApplications == [TokenFixtures.app(1), TokenFixtures.app(2)])

        service.unblock(selection: TokenFixtures.selection(apps: [2]))
        #expect(shields.currentShields().hiddenApplications == [TokenFixtures.app(1)])

        service.unblockAll(blockAllPreventsAppDelete: false)
        #expect(shields.currentShields().hiddenApplications.isEmpty)
    }

    @Test func turningOffHidingKeepsAppsBlocked() {
        let (service, shields) = makeService()
        service.setHidingBlockedApps(true)
        service.blockAll(selection: TokenFixtures.selection(apps: [1]), blockAllPreventsAppDelete: false)

        service.setHidingBlockedApps(false)

        #expect(!service.isHidingBlockedApps)
        #expect(shields.currentShields().hiddenApplications.isEmpty)
        #expect(shields.currentShields().applications == [TokenFixtures.app(1)])
    }

    @Test func blockStatusReflectsTheReconciledShield() {
        let (service, _) = makeService()
        service.blockAll(selection: TokenFixtures.selection(apps: [1, 2]), blockAllPreventsAppDelete: false)
        service.unblock(selection: TokenFixtures.selection(apps: [2]))

        #expect(service.blockStatus(selection: TokenFixtures.selection(apps: [1])) == .all)
        #expect(service.blockStatus(selection: TokenFixtures.selection(apps: [1, 2])) == .some)
        #expect(service.blockStatus(selection: TokenFixtures.selection(apps: [2])) == .none)
        #expect(service.activeShieldCount() == 1)
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
