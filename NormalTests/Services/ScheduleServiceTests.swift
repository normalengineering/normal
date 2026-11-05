import DeviceActivity
import FamilyControls
import Foundation
@testable import Normal
import Testing

@MainActor
struct ScheduleServiceTests {
    private struct TestError: Error {}

    private nonisolated final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private func makeService(clock: Clock = Clock()) -> (
        service: ScheduleService,
        activity: FakeDeviceActivityCenter,
        store: FakeSharedStore
    ) {
        let activity = FakeDeviceActivityCenter()
        let store = FakeSharedStore()
        return (ScheduleService(activityCenter: activity, sharedStore: store, clock: { clock.now }), activity, store)
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

        try service.sync(makeSchedule(isEnabled: true))

        #expect(activity.startCalls.count == 1)
        #expect(activity.stopCalls.count == 1)
    }

    @Test func disabledScheduleOnlyStopsMonitoring() throws {
        let (service, activity, _) = makeService()

        try service.sync(makeSchedule(isEnabled: false))

        #expect(activity.startCalls.isEmpty)
        #expect(activity.stopCalls.count == 1)
    }

    @Test func startMonitoringFailureIsThrown() {
        let (service, activity, _) = makeService()
        activity.startError = TestError()

        #expect(throws: (any Error).self) { try service.sync(makeSchedule()) }
    }

    @Test func removeStopsMonitoringPersistsRemainingAndReconciles() {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let removed = makeSchedule()
        let kept = makeSchedule()

        service.remove(removed, remaining: [kept], screenTimeService: screenTime)

        #expect(activity.stopCalls.last == [DeviceActivityName(SharedConstants.scheduleActivityName(for: removed.id))])
        #expect(store.schedules.map(\.id) == [kept.id])
        #expect(screenTime.reconcileCallCount == 1)
    }

    @Test func toggleEnabledFlipsStatePersistsAndReconciles() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = makeSchedule(isEnabled: true)

        try service.toggleEnabled(schedule, allSchedules: [schedule], screenTimeService: screenTime)
        #expect(!schedule.isEnabled)
        #expect(store.schedules.first?.isEnabled == false)

        try service.toggleEnabled(schedule, allSchedules: [schedule], screenTimeService: screenTime)
        #expect(schedule.isEnabled)
        #expect(store.schedules.first?.isEnabled == true)
        #expect(screenTime.reconcileCallCount == 2)
    }

    @Test func toggleEnabledPersistsEvenWhenMonitoringFails() {
        let (service, activity, store) = makeService()
        activity.startError = TestError()
        let schedule = makeSchedule(isEnabled: false)

        #expect(throws: (any Error).self) {
            try service.toggleEnabled(schedule, allSchedules: [schedule], screenTimeService: FakeScreenTimeService())
        }
        #expect(store.schedules.first?.isEnabled == true)
    }

    @Test func syncAllToSharedStorePersistsDTOs() {
        let (service, _, store) = makeService()
        service.syncAllToSharedStore([makeSchedule()])
        #expect(store.schedules.count == 1)
        #expect(store.schedules.first?.startHour == 9)
        #expect(store.schedules.first?.isEnabled == true)
    }

    @Test func savingAnEnabledScheduleStampsActivationAndKeepsOthers() throws {
        let clock = Clock()
        let (service, _, store) = makeService(clock: clock)
        let first = makeSchedule()
        let second = makeSchedule()
        let firstSaved = clock.now
        try service.syncAndPersist(first, allSchedules: [first], screenTimeService: FakeScreenTimeService())

        clock.now = clock.now.addingTimeInterval(3600)
        try service.syncAndPersist(second, allSchedules: [first, second], screenTimeService: FakeScreenTimeService())
        service.syncAllToSharedStore([second, first])

        let saved = Dictionary(uniqueKeysWithValues: store.schedules.map { ($0.id, $0.activatedAt) })
        #expect(saved[first.id] == firstSaved)
        #expect(saved[second.id] == clock.now)
    }

    @Test func resavingAnEnabledUntimedScheduleKeepsItsActivation() throws {
        let clock = Clock()
        let (service, _, store) = makeService(clock: clock)
        let permanent = BlockSchedule(
            name: "P", selection: FamilyActivitySelection(),
            startHour: 9, startMinute: 0, durationMinutes: 15, weekdays: [1],
            shouldBlock: true, isTimed: false, isEnabled: true
        )
        let activated = clock.now
        try service.syncAndPersist(permanent, allSchedules: [permanent], screenTimeService: FakeScreenTimeService())

        clock.now = clock.now.addingTimeInterval(3600)
        try service.syncAndPersist(permanent, allSchedules: [permanent], screenTimeService: FakeScreenTimeService())

        #expect(store.schedules.first?.activatedAt == activated)
    }

    @Test func savingADisabledScheduleDoesNotStampActivation() throws {
        let (service, _, store) = makeService()
        let schedule = makeSchedule(isEnabled: false)

        try service.syncAndPersist(schedule, allSchedules: [schedule], screenTimeService: FakeScreenTimeService())

        #expect(store.schedules.first?.activatedAt == nil)
    }

    @Test func registerAllReRegistersEnabledOnlyPersistsAllAndReconciles() {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let enabled = makeSchedule(isEnabled: true)
        let disabled = makeSchedule(isEnabled: false)

        service.registerAll([enabled, disabled], screenTimeService: screenTime)

        #expect(store.schedules.count == 2)
        #expect(activity.startCalls.map(\.name.rawValue).filter { $0.hasPrefix("schedule_") }
            == [SharedConstants.scheduleActivityName(for: enabled.id)])
        #expect(screenTime.reconcileCallCount == 1)
    }

    private var heartbeatName: String {
        SharedConstants.reblockHeartbeatActivityName
    }

    @Test func registerAllLeavesUnchangedRegistrationsAlone() throws {
        let (service, activity, _) = makeService()
        let schedule = makeSchedule()
        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())
        activity.startCalls.removeAll()
        activity.stopCalls.removeAll()

        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())
        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())

        #expect(activity.startCalls.isEmpty)
        #expect(activity.stopCalls.isEmpty)
    }

    @Test func registerAllReRegistersWhenTheWindowChanged() throws {
        let (service, activity, _) = makeService()
        let schedule = makeSchedule()
        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())
        activity.startCalls.removeAll()

        schedule.startHour = 10
        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())

        #expect(activity.startCalls.map(\.name.rawValue) == [SharedConstants.scheduleActivityName(for: schedule.id)])
        #expect(activity.startCalls.first?.schedule.intervalStart.hour == 10)
    }

    @Test func registerAllRegistersSchedulesIOSDropped() throws {
        let (service, activity, _) = makeService()
        let schedule = makeSchedule()
        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())
        activity.registeredSchedules.removeAll()
        activity.monitoredActivityNames.removeAll()
        activity.startCalls.removeAll()

        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())

        #expect(activity.startCalls.map(\.name.rawValue).contains(SharedConstants.scheduleActivityName(for: schedule.id)))
    }

    @Test func registerAllStopsOrphanedScheduleActivities() {
        let (service, activity, _) = makeService()
        let orphan = SharedConstants.scheduleActivityName(for: UUID())
        activity.monitoredActivityNames.insert(orphan)
        activity.monitoredActivityNames.insert(SharedConstants.usageLimitsActivityName)

        service.registerAll([makeSchedule()], screenTimeService: FakeScreenTimeService())

        #expect(activity.stopCalls.contains([DeviceActivityName(orphan)]))
        #expect(activity.monitoredActivityNames.contains(SharedConstants.usageLimitsActivityName))
    }

    @Test func heartbeatRunsWhileAnyScheduleIsEnabled() throws {
        let (service, activity, _) = makeService()
        let schedule = makeSchedule()

        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())
        #expect(activity.registeredSchedules[heartbeatName] == DeviceActivityScheduleFactory.heartbeat())

        try service.toggleEnabled(schedule, allSchedules: [schedule], screenTimeService: FakeScreenTimeService())
        #expect(activity.registeredSchedules[heartbeatName] == nil)
    }

    @Test func heartbeatIsNotRestartedWhenAlreadyRunning() {
        let (service, activity, _) = makeService()
        let schedule = makeSchedule()
        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())
        activity.startCalls.removeAll()

        service.registerAll([schedule], screenTimeService: FakeScreenTimeService())

        #expect(!activity.startCalls.map(\.name.rawValue).contains(heartbeatName))
    }

    @Test func heartbeatStaysWhileATimedUnblockIsActiveEvenWithoutSchedules() throws {
        let (service, activity, store) = makeService()
        store.timedUnblocks = try [TimedUnblockDTO(
            id: TimedUnblockService.mainID,
            selectionData: FamilyActivitySelection().toData(),
            endDate: Date(timeIntervalSinceReferenceDate: 800_000_000).addingTimeInterval(3600),
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false
        )]

        service.registerAll([], screenTimeService: FakeScreenTimeService())

        #expect(activity.registeredSchedules[heartbeatName] != nil)
    }

    @Test func heartbeatGetsTheLastFreeActivitySlotBeforeSchedules() {
        let (service, activity, _) = makeService()
        activity.activityLimit = 1

        service.registerAll([makeSchedule(), makeSchedule()], screenTimeService: FakeScreenTimeService())

        #expect(activity.monitoredActivityNames == [heartbeatName])
    }

    @Test func tooManyActivitiesBecomesAReadableError() {
        let (service, activity, _) = makeService()
        activity.startError = DeviceActivityCenter.MonitoringError.excessiveActivities

        #expect(throws: ScheduleRegistrationError.tooManyActivities) { try service.sync(makeSchedule()) }
        #expect(ScheduleRegistrationError.tooManyActivities.errorDescription?.contains("20") == true)
    }

    @Test func sameWindowIgnoresAMissingSecondsComponent() {
        let registered = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 9, minute: 0),
            intervalEnd: DateComponents(hour: 10, minute: 0),
            repeats: true
        )
        let desired = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 9, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 10, minute: 0, second: 0),
            repeats: true
        )
        #expect(registered.hasSameWindow(as: desired))
        #expect(!registered.hasSameWindow(as: DeviceActivitySchedule(
            intervalStart: desired.intervalStart, intervalEnd: desired.intervalEnd, repeats: false
        )))
    }

    @Test func disableAllTogglesEverySchedulePersistsAndReconciles() {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let first = makeSchedule(isEnabled: true)
        let second = makeSchedule(isEnabled: true)

        service.disableAll([first, second], screenTimeService: screenTime)

        #expect(!first.isEnabled)
        #expect(!second.isEnabled)
        #expect(activity.startCalls.isEmpty)
        #expect(store.schedules.allSatisfy { $0.isEnabled == false })
        #expect(screenTime.reconcileCallCount == 1)
    }

    // MARK: - isActive(at:)

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func date(weekday: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.hour = hour
        components.minute = minute
        for day in 1 ... 7 {
            components.day = day
            if let candidate = Self.utc.date(from: components),
               Self.utc.component(.weekday, from: candidate) == weekday
            {
                return candidate
            }
        }
        return Self.utc.date(from: components)!
    }

    private func schedule(
        startHour: Int,
        durationMinutes: Int,
        weekdays: Set<Int>,
        isEnabled: Bool = true
    ) -> BlockSchedule {
        BlockSchedule(
            name: "S",
            selection: FamilyActivitySelection(),
            startHour: startHour, startMinute: 0,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            shouldBlock: true,
            isTimed: true,
            isEnabled: isEnabled
        )
    }

    @Test func isActiveTrueWithinSameDayWindow() {
        let s = schedule(startHour: 9, durationMinutes: 60, weekdays: [4])
        #expect(s.isActive(at: date(weekday: 4, hour: 9, minute: 30), calendar: Self.utc))
    }

    @Test func isActiveFalseOutsideWindowOrWrongDay() {
        let s = schedule(startHour: 9, durationMinutes: 60, weekdays: [4])
        #expect(!s.isActive(at: date(weekday: 4, hour: 10, minute: 30), calendar: Self.utc))
        #expect(!s.isActive(at: date(weekday: 5, hour: 9, minute: 30), calendar: Self.utc))
    }

    @Test func isActiveFalseWhenDisabled() {
        let s = schedule(startHour: 9, durationMinutes: 60, weekdays: [4], isEnabled: false)
        #expect(!s.isActive(at: date(weekday: 4, hour: 9, minute: 30), calendar: Self.utc))
    }

    @Test func isActiveHandlesMidnightWrap() {
        // Wed 23:00 for 3h → ends Thu 02:00.
        let s = schedule(startHour: 23, durationMinutes: 180, weekdays: [4])
        #expect(s.isActive(at: date(weekday: 4, hour: 23, minute: 30), calendar: Self.utc),
                "Active late on the start day")
        #expect(s.isActive(at: date(weekday: 5, hour: 1, minute: 0), calendar: Self.utc),
                "Active early on the next day")
        #expect(!s.isActive(at: date(weekday: 5, hour: 3, minute: 0), calendar: Self.utc),
                "Inactive after the wrapped end")
        #expect(!s.isActive(at: date(weekday: 4, hour: 22, minute: 0), calendar: Self.utc),
                "Inactive before the start")
    }

    @Test func mirrorCustomDomainsEnabledWritesFlag() {
        let (service, _, store) = makeService()

        service.mirrorCustomDomainsEnabled(true)
        #expect(store.isCustomDomainsEnabled())

        service.mirrorCustomDomainsEnabled(false)
        #expect(!store.isCustomDomainsEnabled())
    }

    private func registeredSchedule(
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int,
        isTimed: Bool
    ) throws -> DeviceActivitySchedule {
        let (service, activity, _) = makeService()
        let schedule = BlockSchedule(
            name: "S",
            selection: FamilyActivitySelection(),
            startHour: startHour, startMinute: startMinute,
            durationMinutes: durationMinutes,
            weekdays: [4],
            shouldBlock: true,
            isTimed: isTimed,
            isEnabled: true
        )
        try service.sync(schedule)
        return try #require(activity.startCalls.last?.schedule)
    }

    @Test func registersRequestedWindow() throws {
        let registered = try registeredSchedule(startHour: 22, startMinute: 30, durationMinutes: 240, isTimed: true)
        #expect(registered.intervalStart == DateComponents(hour: 22, minute: 30, second: 0))
        #expect(registered.intervalEnd == DateComponents(hour: 2, minute: 30, second: 0))
        #expect(registered.repeats)
    }

    @Test func permanentScheduleShorterThanMinimumRegistersMinimumWindow() throws {
        let registered = try registeredSchedule(startHour: 9, startMinute: 55, durationMinutes: 5, isTimed: false)
        #expect(registered.intervalStart == DateComponents(hour: 9, minute: 55, second: 0))
        #expect(registered.intervalEnd == DateComponents(hour: 10, minute: 10, second: 0))
    }

    @Test func fullDayScheduleEndsOneSecondBeforeStart() throws {
        let registered = try registeredSchedule(startHour: 9, startMinute: 0, durationMinutes: 1440, isTimed: true)
        #expect(registered.intervalStart == DateComponents(hour: 9, minute: 0, second: 0))
        #expect(registered.intervalEnd == DateComponents(hour: 8, minute: 59, second: 59))
    }

    @Test func shortPermanentScheduleUsesMinimumWindowForActivityAndDTO() throws {
        let s = BlockSchedule(
            name: "S",
            selection: FamilyActivitySelection(),
            startHour: 9, startMinute: 0,
            durationMinutes: 5,
            weekdays: [4],
            shouldBlock: true,
            isTimed: false,
            isEnabled: true
        )
        #expect(s.isActive(at: date(weekday: 4, hour: 9, minute: 10), calendar: Self.utc))
        #expect(!s.isActive(at: date(weekday: 4, hour: 9, minute: 15), calendar: Self.utc))
        #expect(try #require(s.toDTO()).durationMinutes == 15)
        #expect(s.durationMinutes == 5)
    }
}
