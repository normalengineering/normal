@testable import Normal
import FamilyControls
import Foundation
import Testing

@MainActor
struct TimedUnblockServiceTests {
    private func makeService() -> (
        service: TimedUnblockService,
        activity: FakeDeviceActivityCenter,
        store: FakeSharedStore
    ) {
        let activity = FakeDeviceActivityCenter()
        let store = FakeSharedStore()
        let service = TimedUnblockService(
            activityCenter: activity,
            sharedStore: store,
            onExpiration: {}
        )
        return (service, activity, store)
    }

    @Test func startMainRemovesShieldAndPersists() throws {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(screenTime.removeShieldOnAllCalled)
        #expect(activity.startCalls.count == 1)
        #expect(store.timedUnblocks.count == 1)
        #expect(service.isMainUnblockActive)
    }

    @Test func startGroupRemovesFromShieldsAndPersists() throws {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupId = UUID()

        try service.startGroup(
            duration: .fifteenMinutes,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(screenTime.removeFromShieldsCalled)
        #expect(activity.startCalls.count == 1)
        #expect(store.timedUnblocks.count == 1)
        #expect(service.isGroupUnblockActive(groupId: groupId))
    }

    @Test func cancelMainAppliesShieldsAndForgets() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        service.cancelMain(
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime,
            preventAppDelete: false
        )

        #expect(screenTime.applyShieldOnAllCalled)
        #expect(store.timedUnblocks.isEmpty)
        #expect(!service.isMainUnblockActive)
    }

    @Test func cancelGroupReinstatesShieldsAndForgets() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupId = UUID()

        try service.startGroup(
            duration: .fifteenMinutes,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        service.cancelGroup(
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(screenTime.addToShieldsCalled)
        #expect(store.timedUnblocks.isEmpty)
        #expect(!service.isGroupUnblockActive(groupId: groupId))
    }

    @Test func startMainCancelsExistingGroupUnblocks() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupId = UUID()

        try service.startGroup(
            duration: .fifteenMinutes,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        try service.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(!service.isGroupUnblockActive(groupId: groupId))
        #expect(service.isMainUnblockActive)
        #expect(store.timedUnblocks.count == 1)
    }

    @Test func updateMainSelectionPreservesEndDate() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()

        try service.startMain(
            duration: .oneHour,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        let originalEnd = store.timedUnblocks.first?.endDate

        service.updateMainSelection(FamilyActivitySelection())

        #expect(store.timedUnblocks.first?.endDate == originalEnd)
    }

    @Test func restoresActiveUnblocksFromStore() {
        let activity = FakeDeviceActivityCenter()
        let store = FakeSharedStore()
        let futureEnd = Date.now.addingTimeInterval(3600)
        let dto = try! TimedUnblockDTO(
            id: TimedUnblockService.mainID,
            selectionData: FamilyActivitySelection().toData(),
            endDate: futureEnd,
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false
        )
        store.timedUnblocks = [dto]

        let service = TimedUnblockService(
            activityCenter: activity,
            sharedStore: store,
            onExpiration: {}
        )

        #expect(service.isMainUnblockActive)
    }

    @Test func discardsExpiredUnblocksOnRestore() {
        let store = FakeSharedStore()
        let pastEnd = Date.now.addingTimeInterval(-60)
        let dto = try! TimedUnblockDTO(
            id: TimedUnblockService.mainID,
            selectionData: FamilyActivitySelection().toData(),
            endDate: pastEnd,
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false
        )
        store.timedUnblocks = [dto]

        let service = TimedUnblockService(
            activityCenter: FakeDeviceActivityCenter(),
            sharedStore: store,
            onExpiration: {}
        )

        #expect(!service.isMainUnblockActive)
        #expect(store.timedUnblocks.isEmpty)
    }
}
