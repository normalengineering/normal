@testable import Normal
import FamilyControls
import Testing

@MainActor
struct ScheduleServiceTests {
    private func makeService() -> (
        service: ScheduleService,
        activity: FakeDeviceActivityCenter,
        store: FakeSharedStore
    ) {
        let activity = FakeDeviceActivityCenter()
        let store = FakeSharedStore()
        return (ScheduleService(activityCenter: activity, sharedStore: store), activity, store)
    }

    private func makeSchedule(
        shouldBlock: Bool = true,
        isEnabled: Bool = true
    ) -> BlockSchedule {
        BlockSchedule(
            name: "Work",
            selection: FamilyActivitySelection(),
            startHour: 9, startMinute: 0,
            durationMinutes: 60,
            weekdays: [2, 3, 4, 5, 6],
            shouldBlock: shouldBlock,
            isTimed: true,
            isEnabled: isEnabled
        )
    }

    @Test func enabledScheduleStartsMonitoring() throws {
        let (service, activity, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = makeSchedule(isEnabled: true)

        try service.sync(schedule, screenTimeService: screenTime)

        #expect(activity.startCalls.count == 1)
        #expect(activity.stopCalls.count == 1)
    }

    @Test func disabledBlockingScheduleRemovesFromShields() throws {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = makeSchedule(shouldBlock: true, isEnabled: false)

        try service.sync(schedule, screenTimeService: screenTime)

        #expect(screenTime.removeFromShieldsCalled)
    }

    @Test func disabledUnblockScheduleDoesNotBlock() throws {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = makeSchedule(shouldBlock: false, isEnabled: false)

        try service.sync(schedule, screenTimeService: screenTime)

        #expect(!screenTime.addToShieldsCalled)
    }

    @Test func removeBlockingScheduleRemovesFromShields() {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = makeSchedule(shouldBlock: true)

        service.remove(schedule, screenTimeService: screenTime)

        #expect(screenTime.removeFromShieldsCalled)
    }

    @Test func removeUnblockingScheduleDoesNotBlock() {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = makeSchedule(shouldBlock: false)

        service.remove(schedule, screenTimeService: screenTime)

        #expect(!screenTime.addToShieldsCalled)
    }

    @Test func toggleEnabledFlipsState() throws {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = makeSchedule(isEnabled: true)

        try service.toggleEnabled(schedule, screenTimeService: screenTime)
        #expect(!schedule.isEnabled)

        try service.toggleEnabled(schedule, screenTimeService: screenTime)
        #expect(schedule.isEnabled)
    }

    @Test func syncAllToSharedStorePersistsDTOs() {
        let (service, _, store) = makeService()
        let schedule = makeSchedule()
        service.syncAllToSharedStore([schedule])
        #expect(store.schedules.count == 1)
        #expect(store.schedules.first?.startHour == 9)
    }
}
