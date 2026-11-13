import FamilyControls
@testable import Normal
import Testing

@MainActor
struct UnblockTargetTests {
    private let activity = FakeDeviceActivityCenter()
    private let store = FakeSharedStore()
    private let screenTime = FakeScreenTimeService()
    private let service: TimedUnblockService

    init() {
        service = TimedUnblockService(activityCenter: activity, sharedStore: store, onExpiration: {})
    }

    private func settings(customDomains: Bool) -> Settings {
        let settings = Settings()
        settings.enableCustomDomains = customDomains
        settings.blockAllPreventsAppDelete = false
        return settings
    }

    @Test func startingAllStartsTheMainUnblock() throws {
        let main = SelectedApps(selection: FamilyActivitySelection(), customDomains: ["a.com"])

        try service.start(.all(main), duration: .oneHour, settings: settings(customDomains: true), screenTimeService: screenTime)

        #expect(service.isMainUnblockActive)
        #expect(store.timedUnblocks.first?.customDomains == ["a.com"])
        #expect(store.timedUnblocks.first?.isGroupUnblock == false)
    }

    @Test func startingAGroupStartsItsUnblock() throws {
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection(), customDomains: ["b.com"])

        try service.start(.group(group), duration: .oneHour, settings: settings(customDomains: true), screenTimeService: screenTime)

        #expect(service.isGroupUnblockActive(groupId: group.id))
        #expect(store.timedUnblocks.first?.customDomains == ["b.com"])
        #expect(store.timedUnblocks.first?.isGroupUnblock == true)
    }

    @Test func customDomainsAreLeftOutWhenTurnedOff() throws {
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection(), customDomains: ["b.com"])

        try service.start(.group(group), duration: .oneHour, settings: settings(customDomains: false), screenTimeService: screenTime)

        #expect(store.timedUnblocks.first?.customDomains == [])
    }

    @Test func permanentlyUnblockingAllUnblocksEverything() {
        let main = SelectedApps(selection: FamilyActivitySelection())

        screenTime.unblockPermanently(.all(main), settings: settings(customDomains: true))

        #expect(screenTime.unblockAllCalled)
        #expect(screenTime.unblockAllPreventsAppDelete == false)
        #expect(!screenTime.unblockCalled)
    }

    @Test func permanentlyUnblockingAGroupUnblocksItsSelection() {
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection(), customDomains: ["b.com"])

        screenTime.unblockPermanently(.group(group), settings: settings(customDomains: true))

        #expect(screenTime.unblockCalled)
        #expect(screenTime.unblockCustomDomains == ["b.com"])
        #expect(!screenTime.unblockAllCalled)
    }
}
