import FamilyControls
import Foundation
@testable import Normal
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

    @Test func registerAllReRegistersEnabledOnlyAndPersistsAll() {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let enabled = makeSchedule(isEnabled: true)
        let disabled = makeSchedule(isEnabled: false)

        service.registerAll([enabled, disabled], screenTimeService: screenTime)

        #expect(store.schedules.count == 2, "All schedules persisted to the shared store")
        #expect(activity.startCalls.count == 1, "Only the enabled schedule is (re)registered")
    }

    // MARK: - "Unblock all" overrides

    private func activeNowSchedule(shouldBlock: Bool = true) -> BlockSchedule {
        let now = Date()
        let calendar = Calendar.current
        return BlockSchedule(
            name: "ActiveNow",
            selection: FamilyActivitySelection(),
            startHour: calendar.component(.hour, from: now),
            startMinute: 0,
            durationMinutes: 120,
            weekdays: [calendar.component(.weekday, from: now)],
            shouldBlock: shouldBlock,
            isTimed: true,
            isEnabled: true
        )
    }

    private func activeMainUnblock() -> TimedUnblockDTO {
        try! TimedUnblockDTO(
            id: TimedUnblockService.mainID,
            selectionData: FamilyActivitySelection().toData(),
            endDate: .now.addingTimeInterval(.hours(1)),
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false
        )
    }

    @Test func activeScheduleBlocksWhenNoUnblockInEffect() throws {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()

        try service.sync(activeNowSchedule(), screenTimeService: screenTime)

        #expect(screenTime.addToShieldsCalled, "An active block schedule applies when nothing overrides it")
    }

    @Test func activeScheduleSuppressedDuringTimedUnblock() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        store.timedUnblocks = [activeMainUnblock()]

        try service.sync(activeNowSchedule(), screenTimeService: screenTime)

        #expect(!screenTime.addToShieldsCalled, "A live timed unblock-all must override schedule blocking")
    }

    @Test func activeScheduleSuppressedDuringPermanentOverride() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        store.setScheduleOverrideActive(true)

        try service.sync(activeNowSchedule(), screenTimeService: screenTime)

        #expect(!screenTime.addToShieldsCalled, "A permanent unblock-all override must suppress schedule blocking")
    }

    @Test func reapplyDoesNotConsumePermanentOverride() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        store.setScheduleOverrideActive(true)

        try service.sync(activeNowSchedule(), screenTimeService: screenTime)

        #expect(store.isScheduleOverrideActive(),
                "Foreground re-application must not consume the override; only a fresh start does")
    }

    @Test func setScheduleOverrideWritesFlag() {
        let (service, _, store) = makeService()

        service.setScheduleOverride(true)
        #expect(store.isScheduleOverrideActive())

        service.setScheduleOverride(false)
        #expect(!store.isScheduleOverrideActive())
    }

    @Test func disableAllTogglesEveryScheduleOff() {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let first = makeSchedule(isEnabled: true)
        let second = makeSchedule(isEnabled: true)

        service.disableAll([first, second], screenTimeService: screenTime)

        #expect(!first.isEnabled)
        #expect(!second.isEnabled)
    }

    @Test func disableAllStopsMonitoringAndLiftsBlocks() {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = makeSchedule(shouldBlock: true, isEnabled: true)

        service.disableAll([schedule], screenTimeService: screenTime)

        #expect(activity.startCalls.isEmpty, "Disabled schedules are not monitored")
        #expect(!activity.stopCalls.isEmpty, "Monitoring is stopped for the disabled schedule")
        #expect(screenTime.removeFromShieldsCalled, "A blocking schedule's shield is lifted when disabled")
        #expect(store.schedules.count == 1, "The disabled schedule is still persisted to the shared store")
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

    private func activeDomainSchedule() -> BlockSchedule {
        let schedule = activeNowSchedule(shouldBlock: true)
        schedule.customDomains = ["reddit.com"]
        return schedule
    }

    @Test func activeScheduleOmitsDomainsWhenFeatureDisabled() throws {
        let (service, _, _) = makeService() // FakeSharedStore defaults customDomainsEnabled = false
        let screenTime = FakeScreenTimeService()

        try service.sync(activeDomainSchedule(), screenTimeService: screenTime)

        #expect(screenTime.addToShieldsCalled)
        #expect(screenTime.addToShieldsCustomDomains == [], "Domains must not enforce while the setting is off")
    }

    @Test func activeScheduleAppliesDomainsWhenFeatureEnabled() throws {
        let (service, _, store) = makeService()
        store.setCustomDomainsEnabled(true)
        let screenTime = FakeScreenTimeService()

        try service.sync(activeDomainSchedule(), screenTimeService: screenTime)

        #expect(screenTime.addToShieldsCustomDomains == ["reddit.com"])
    }

    @Test func disabledBlockingScheduleOmitsDomainsWhenFeatureDisabled() throws {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let schedule = activeDomainSchedule()
        schedule.isEnabled = false

        try service.sync(schedule, screenTimeService: screenTime)

        #expect(screenTime.removeFromShieldsCalled)
        #expect(screenTime.removeFromShieldsCustomDomains == [])
    }

    @Test func mirrorCustomDomainsEnabledWritesFlag() {
        let (service, _, store) = makeService()

        service.mirrorCustomDomainsEnabled(true)
        #expect(store.isCustomDomainsEnabled())

        service.mirrorCustomDomainsEnabled(false)
        #expect(!store.isCustomDomainsEnabled())
    }
}
