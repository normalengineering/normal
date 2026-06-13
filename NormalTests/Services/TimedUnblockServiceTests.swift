import DeviceActivity
import FamilyControls
import Foundation
@testable import Normal
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
            blockAllPreventsAppDelete: false
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

    @Test func startMainClearsPermanentScheduleOverride() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        store.setScheduleOverrideActive(true)

        try service.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(!store.isScheduleOverrideActive(),
                "A timed unblock supersedes a permanent override; its own window guard takes over")
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

    @Test func clearAllStopsEveryUnblockAndForgets() throws {
        let (service, activity, store) = makeService()
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

        let stopsBefore = activity.stopCalls.count
        service.clearAll()

        #expect(!service.isMainUnblockActive)
        #expect(!service.isGroupUnblockActive(groupId: groupId))
        #expect(store.timedUnblocks.isEmpty)
        #expect(activity.stopCalls.count > stopsBefore)
    }

    @Test func clearAllWithNothingActiveIsNoOp() {
        let (service, _, store) = makeService()

        service.clearAll()

        #expect(!service.isMainUnblockActive)
        #expect(store.timedUnblocks.isEmpty)
    }

    @Test func clearAllLeavesSchedulesUntouched() throws {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let scheduleId = UUID()
        let schedule = try ScheduleDTO(
            id: scheduleId,
            name: "Work",
            selectionData: FamilyActivitySelection().toData(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 60,
            weekdays: [2, 3, 4, 5, 6],
            shouldBlock: true,
            isTimed: true
        )
        store.saveSchedules([schedule])

        try service.startGroup(
            duration: .fifteenMinutes,
            groupId: UUID(),
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        service.clearAll()

        #expect(store.loadSchedules().map(\.id) == [scheduleId])
        let scheduleActivity = SharedConstants.scheduleActivityName(for: scheduleId)
        let stoppedNames = activity.stopCalls.flatMap { $0 }.map(\.rawValue)
        #expect(!stoppedNames.contains(scheduleActivity))
        #expect(store.timedUnblocks.isEmpty)
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
        let futureEnd = Date.now.addingTimeInterval(.hours(1))
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
        let pastEnd = Date.now.addingTimeInterval(-.minutes(1))
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

    // MARK: - Multiple simultaneous group unblocks

    @discardableResult
    private func startGroup(
        _ service: TimedUnblockService,
        _ screenTime: FakeScreenTimeService,
        _ groupId: UUID,
        duration: UnblockDuration = .fifteenMinutes
    ) throws -> String {
        try service.startGroup(
            duration: duration,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        return groupId.uuidString
    }

    private func groupActivityName(_ groupId: UUID) -> String {
        SharedConstants.groupTimedUnblockActivityName(for: groupId)
    }

    @Test func twoGroupsUnblockIndependently() throws {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupA = UUID()
        let groupB = UUID()

        try startGroup(service, screenTime, groupA)
        try startGroup(service, screenTime, groupB)

        #expect(service.isGroupUnblockActive(groupId: groupA))
        #expect(service.isGroupUnblockActive(groupId: groupB))
        #expect(Set(store.timedUnblocks.map(\.id)) == [groupA.uuidString, groupB.uuidString])

        let started = activity.startCalls.map(\.name.rawValue)
        #expect(started.contains(groupActivityName(groupA)))
        #expect(started.contains(groupActivityName(groupB)))
    }

    @Test func cancellingOneGroupLeavesTheOtherActive() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupA = UUID()
        let groupB = UUID()

        try startGroup(service, screenTime, groupA)
        try startGroup(service, screenTime, groupB)
        service.cancelGroup(
            groupId: groupA,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(!service.isGroupUnblockActive(groupId: groupA))
        #expect(service.isGroupUnblockActive(groupId: groupB))
        #expect(store.timedUnblocks.map(\.id) == [groupB.uuidString])
    }

    @Test func eachGroupKeepsItsOwnEndDate() throws {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let shortGroup = UUID()
        let longGroup = UUID()

        try startGroup(service, screenTime, shortGroup, duration: .fifteenMinutes)
        try startGroup(service, screenTime, longGroup, duration: .fourHours)

        let shortEnd = try #require(service.groupUnblockEndDate(groupId: shortGroup))
        let longEnd = try #require(service.groupUnblockEndDate(groupId: longGroup))
        #expect(longEnd > shortEnd)
    }

    @Test func reUnblockingSameGroupReplacesItsEntry() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let group = UUID()

        try startGroup(service, screenTime, group, duration: .fifteenMinutes)
        let firstEnd = try #require(service.groupUnblockEndDate(groupId: group))
        try startGroup(service, screenTime, group, duration: .fourHours)

        #expect(store.timedUnblocks.map(\.id) == [group.uuidString], "Same group is upserted, not duplicated")
        let secondEnd = try #require(service.groupUnblockEndDate(groupId: group))
        #expect(secondEnd > firstEnd, "End date extends to the new duration")
    }

    @Test func startMainCancelsMultipleGroupUnblocks() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupA = UUID()
        let groupB = UUID()

        try startGroup(service, screenTime, groupA)
        try startGroup(service, screenTime, groupB)
        try service.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(!service.isGroupUnblockActive(groupId: groupA))
        #expect(!service.isGroupUnblockActive(groupId: groupB))
        #expect(service.isMainUnblockActive)
        #expect(store.timedUnblocks.map(\.id) == [TimedUnblockService.mainID])
    }

    @Test func clearAllRemovesEveryGroupUnblock() throws {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupA = UUID()
        let groupB = UUID()

        try startGroup(service, screenTime, groupA)
        try startGroup(service, screenTime, groupB)
        service.clearAll()

        #expect(!service.isGroupUnblockActive(groupId: groupA))
        #expect(!service.isGroupUnblockActive(groupId: groupB))
        #expect(store.timedUnblocks.isEmpty)

        let stopped = activity.stopCalls.flatMap { $0 }.map(\.rawValue)
        #expect(stopped.contains(groupActivityName(groupA)))
        #expect(stopped.contains(groupActivityName(groupB)))
    }

    @Test func cancellingOneGroupDoesNotTouchAnother() throws {
        let (service, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupA = UUID()
        let groupB = UUID()

        try startGroup(service, screenTime, groupA)
        try startGroup(service, screenTime, groupB)
        let endBBefore = try #require(service.groupUnblockEndDate(groupId: groupB))

        service.cancelGroup(
            groupId: groupA,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(service.groupUnblockEndDate(groupId: groupB) == endBBefore)
    }
}

@MainActor
struct DeviceActivityScheduleFactoryTests {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func date(hour: Int, minute: Int, second: Int = 0) -> Date {
        Self.utc.date(from: DateComponents(
            year: 2026, month: 6, day: 1, hour: hour, minute: minute, second: second
        ))!
    }

    private func intervalSeconds(_ schedule: DeviceActivitySchedule) -> TimeInterval {
        let start = Self.utc.date(from: schedule.intervalStart)!
        let end = Self.utc.date(from: schedule.intervalEnd)!
        return end.timeIntervalSince(start)
    }

    @Test func fifteenMinuteWindowIsFlooredAboveTheMinimum() {
        let start = date(hour: 10, minute: 0)
        let schedule = DeviceActivityScheduleFactory.window(
            from: start, to: start.addingTimeInterval(.minutes(15)), calendar: Self.utc
        )
        #expect(intervalSeconds(schedule) > .minutes(15))
    }

    @Test func longerWindowIsPreservedExactly() {
        let start = date(hour: 10, minute: 0)
        let schedule = DeviceActivityScheduleFactory.window(
            from: start, to: start.addingTimeInterval(.hours(1)), calendar: Self.utc
        )
        #expect(intervalSeconds(schedule) == .hours(1))
    }
}
