@testable import Normal
import FamilyControls
import Foundation
import SwiftData
import Testing

struct ScheduleServiceTests {
    @MainActor
    private func makeSUT() -> (ScheduleService, MockDeviceActivityCenter, MockSharedStore, MockScreenTimeService) {
        let activityCenter = MockDeviceActivityCenter()
        let sharedStore = MockSharedStore()
        let screenTimeService = MockScreenTimeService()
        let service = ScheduleService(activityCenter: activityCenter, sharedStore: sharedStore)
        return (service, activityCenter, sharedStore, screenTimeService)
    }

    @MainActor
    private func makeSchedule(
        context: ModelContext,
        shouldBlock: Bool = true,
        isTimed: Bool = true,
        isEnabled: Bool = true
    ) -> BlockSchedule {
        let schedule = BlockSchedule(
            name: "Test",
            selection: FamilyActivitySelection(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 120,
            weekdays: [2, 3, 4, 5, 6],
            shouldBlock: shouldBlock,
            isTimed: isTimed,
            isEnabled: isEnabled
        )
        context.insert(schedule)
        return schedule
    }

    @Test @MainActor func syncEnabledScheduleStartsMonitoring() throws {
        let (service, activityCenter, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext)

        try service.sync(schedule, screenTimeService: screenTimeService)

        #expect(activityCenter.stopMonitoringCalled)
        #expect(activityCenter.startMonitoringCalled)
    }

    @Test @MainActor func syncDisabledBlockScheduleRemovesFromShields() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(
            context: container.mainContext,
            shouldBlock: true,
            isEnabled: false
        )

        try service.sync(schedule, screenTimeService: screenTimeService)

        #expect(screenTimeService.removeFromShieldsCalled)
        #expect(!screenTimeService.addToShieldsCalled)
    }

    @Test @MainActor func syncDisabledUnblockScheduleAddsToShields() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(
            context: container.mainContext,
            shouldBlock: false,
            isEnabled: false
        )

        try service.sync(schedule, screenTimeService: screenTimeService)

        #expect(screenTimeService.addToShieldsCalled)
        #expect(!screenTimeService.removeFromShieldsCalled)
    }

    @Test @MainActor func removeBlockScheduleRemovesFromShields() throws {
        let (service, activityCenter, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext, shouldBlock: true)

        service.remove(schedule, screenTimeService: screenTimeService)

        #expect(activityCenter.stopMonitoringCalled)
        #expect(screenTimeService.removeFromShieldsCalled)
    }

    @Test @MainActor func removeUnblockScheduleAddsToShields() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext, shouldBlock: false)

        service.remove(schedule, screenTimeService: screenTimeService)

        #expect(screenTimeService.addToShieldsCalled)
    }

    @Test @MainActor func toggleEnabledFlipsAndSyncs() throws {
        let (service, activityCenter, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext, isEnabled: true)

        try service.toggleEnabled(schedule, screenTimeService: screenTimeService)

        #expect(!schedule.isEnabled)
        #expect(activityCenter.stopMonitoringCalled)
    }

    @Test @MainActor func syncAllToSharedStoreWritesDTOs() throws {
        let (service, _, sharedStore, _) = makeSUT()
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let s1 = makeSchedule(context: context)
        let s2 = makeSchedule(context: context)

        service.syncAllToSharedStore([s1, s2])

        #expect(sharedStore.schedules.count == 2)
    }

    @Test @MainActor func syncStopsExistingMonitoringBeforeStarting() throws {
        let (service, activityCenter, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext)

        try service.sync(schedule, screenTimeService: screenTimeService)

        #expect(activityCenter.stopMonitoringCalled)
        #expect(activityCenter.startMonitoringCalled)
    }

    @Test @MainActor func newScheduleDefaultsToDisabled() throws {
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext, isEnabled: false)

        #expect(!schedule.isEnabled)
    }

    @Test @MainActor func newDisabledScheduleDoesNotStartMonitoring() throws {
        let (service, activityCenter, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext, isEnabled: false)

        try service.sync(schedule, screenTimeService: screenTimeService)

        #expect(activityCenter.stopMonitoringCalled)
        #expect(!activityCenter.startMonitoringCalled)
    }

    @Test @MainActor func toggleDisabledToEnabledStartsMonitoring() throws {
        let (service, activityCenter, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext, isEnabled: false)

        try service.toggleEnabled(schedule, screenTimeService: screenTimeService)

        #expect(schedule.isEnabled)
        #expect(activityCenter.startMonitoringCalled)
    }

    @Test @MainActor func toggleEnabledToDisabledStopsMonitoring() throws {
        let (service, activityCenter, _, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext, isEnabled: true)

        try service.toggleEnabled(schedule, screenTimeService: screenTimeService)

        #expect(!schedule.isEnabled)
        #expect(activityCenter.stopMonitoringCalled)
        #expect(!activityCenter.startMonitoringCalled)
    }

    @Test @MainActor func syncAllToSharedStoreIncludesDisabledSchedules() throws {
        let (service, _, sharedStore, _) = makeSUT()
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let enabled = makeSchedule(context: context, isEnabled: true)
        let disabled = makeSchedule(context: context, isEnabled: false)

        service.syncAllToSharedStore([enabled, disabled])

        #expect(sharedStore.schedules.count == 2)
    }

    @Test @MainActor func syncAndPersistDisabledScheduleDoesNotStartMonitoring() throws {
        let (service, activityCenter, sharedStore, screenTimeService) = makeSUT()
        let container = try makeTestModelContainer()
        let schedule = makeSchedule(context: container.mainContext, isEnabled: false)

        try service.syncAndPersist(
            schedule,
            allSchedules: [schedule],
            screenTimeService: screenTimeService
        )

        #expect(!activityCenter.startMonitoringCalled)
        #expect(sharedStore.schedules.count == 1)
    }
}
