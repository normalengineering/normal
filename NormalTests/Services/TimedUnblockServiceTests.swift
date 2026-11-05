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

    @Test func startMainPersistsAndReconciles() throws {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(screenTime.reconcileCallCount == 1)
        #expect(activity.startCalls.map(\.name.rawValue) == [
            SharedConstants.mainTimedUnblockActivityName,
            SharedConstants.reblockHeartbeatActivityName,
        ])
        #expect(store.timedUnblocks.count == 1)
        #expect(service.isMainUnblockActive)
    }

    @Test func startGroupPersistsAndReconciles() throws {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupId = UUID()

        try service.startGroup(
            duration: .fifteenMinutes,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        #expect(screenTime.reconcileCallCount == 1)
        #expect(activity.startCalls.map(\.name.rawValue) == [
            SharedConstants.groupTimedUnblockActivityName(for: groupId),
            SharedConstants.reblockHeartbeatActivityName,
        ])
        #expect(store.timedUnblocks.count == 1)
        #expect(service.isGroupUnblockActive(groupId: groupId))
    }

    private struct RegistrationFailed: Error {}

    @Test func startMainRegistrationFailureLeavesShieldsAndGroupUnblocks() throws {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupId = UUID()
        try service.startGroup(
            duration: .fifteenMinutes,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        activity.startError = RegistrationFailed()

        #expect(throws: RegistrationFailed.self) {
            try service.startMain(
                duration: .fifteenMinutes,
                selection: FamilyActivitySelection(),
                screenTimeService: screenTime
            )
        }

        #expect(!screenTime.unblockAllCalled)
        #expect(!service.isMainUnblockActive)
        #expect(service.isGroupUnblockActive(groupId: groupId))
        #expect(store.timedUnblocks.map(\.id) == [groupId.uuidString])
    }

    @Test func startGroupRegistrationFailureLeavesShields() {
        let (service, activity, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupId = UUID()
        activity.startError = RegistrationFailed()

        #expect(throws: RegistrationFailed.self) {
            try service.startGroup(
                duration: .fifteenMinutes,
                groupId: groupId,
                selection: FamilyActivitySelection(),
                screenTimeService: screenTime
            )
        }

        #expect(!screenTime.unblockCalled)
        #expect(!service.isGroupUnblockActive(groupId: groupId))
        #expect(store.timedUnblocks.isEmpty)
    }

    @Test func customDurationSetsEndDateAndPersistsStartDate() throws {
        let (service, _, store) = makeService()
        let custom = try #require(TimedUnblockDuration(validating: 5700))
        let before = Date.now

        try service.startMain(
            duration: custom,
            selection: FamilyActivitySelection(),
            screenTimeService: FakeScreenTimeService()
        )

        let dto = try #require(store.timedUnblocks.first)
        let start = try #require(dto.startDate)
        #expect(start >= before)
        #expect(dto.endDate.timeIntervalSince(start) == 5700)
        #expect(service.activeUnblockStartDates()[TimedUnblockService.mainID] == start)
    }

    @Test func updatingSelectionKeepsOriginalStartDate() throws {
        let (service, _, store) = makeService()
        let groupId = UUID()
        try service.startMain(
            duration: .oneHour,
            selection: FamilyActivitySelection(),
            screenTimeService: FakeScreenTimeService()
        )
        let mainStart = try #require(store.timedUnblocks.first?.startDate)

        service.updateMainSelection(FamilyActivitySelection(), customDomains: ["x.com"], screenTimeService: FakeScreenTimeService())

        let updated = try #require(store.timedUnblocks.first { $0.id == TimedUnblockService.mainID })
        #expect(updated.startDate == mainStart)
        #expect(updated.customDomains == ["x.com"])

        try service.startGroup(
            duration: .oneHour,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: FakeScreenTimeService()
        )
        let groupStart = try #require(store.timedUnblocks.first { $0.id == groupId.uuidString }?.startDate)
        service.updateGroupSelection(groupId: groupId, selection: FamilyActivitySelection())
        #expect(store.timedUnblocks.first { $0.id == groupId.uuidString }?.startDate == groupStart)
    }

    @Test func legacyUnblockWithoutStartDateHasNoStartDate() throws {
        let (service, _, store) = makeService()
        store.timedUnblocks = try [
            TimedUnblockDTO(
                id: TimedUnblockService.mainID,
                selectionData: FamilyActivitySelection().toData(),
                endDate: .now.addingTimeInterval(600),
                activityName: SharedConstants.mainTimedUnblockActivityName,
                isGroupUnblock: false
            ),
        ]
        service.reconcile(screenTimeService: FakeScreenTimeService())

        #expect(service.isMainUnblockActive)
        #expect(service.activeUnblockStartDates().isEmpty, "Live Activity falls back to now")
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

        #expect(screenTime.blockAllCalled)
        #expect(store.timedUnblocks.isEmpty)
        #expect(!service.isMainUnblockActive)
    }

    @Test func cancelGroupForgetsTheUnblock() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupId = UUID()

        try service.startGroup(
            duration: .fifteenMinutes,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        service.cancelGroup(groupId: groupId)

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

        service.updateMainSelection(FamilyActivitySelection(), screenTimeService: FakeScreenTimeService())

        #expect(store.timedUnblocks.first?.endDate == originalEnd)
    }

    @Test func restoresActiveUnblocksFromStore() throws {
        let activity = FakeDeviceActivityCenter()
        let store = FakeSharedStore()
        let futureEnd = Date.now.addingTimeInterval(.hours(1))
        let dto = try TimedUnblockDTO(
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

    private func expiredMainDTO(blockAllPreventsAppDelete: Bool? = nil) -> TimedUnblockDTO {
        try! TimedUnblockDTO(
            id: TimedUnblockService.mainID,
            selectionData: FamilyActivitySelection().toData(),
            endDate: Date.now.addingTimeInterval(-.minutes(1)),
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false,
            blockAllPreventsAppDelete: blockAllPreventsAppDelete
        )
    }

    @Test func expiredUnblockIsRetainedNotActiveAtInit() {
        let store = FakeSharedStore()
        store.timedUnblocks = [expiredMainDTO()]

        let service = TimedUnblockService(
            activityCenter: FakeDeviceActivityCenter(),
            sharedStore: store,
            onExpiration: {}
        )

        #expect(!service.isMainUnblockActive)
        #expect(store.timedUnblocks.count == 1)
    }

    @Test func heartbeatRepeatsEveryHalfHour() {
        let heartbeat = DeviceActivityScheduleFactory.heartbeat()
        #expect(heartbeat.intervalStart == DateComponents(minute: 0, second: 0))
        #expect(heartbeat.intervalEnd == DateComponents(minute: 30, second: 0))
        #expect(heartbeat.repeats)
    }

    @Test func reconcileStopsHeartbeatOnceNoUnblocksRemain() {
        let (service, activity, store) = makeService()
        store.timedUnblocks = [expiredMainDTO()]
        let heartbeat = DeviceActivityName(SharedConstants.reblockHeartbeatActivityName)
        try? activity.startMonitoring(heartbeat, during: DeviceActivityScheduleFactory.heartbeat(), events: [:])
        activity.startCalls.removeAll()

        service.reconcile(screenTimeService: FakeScreenTimeService())

        #expect(activity.stopCalls.last == [heartbeat])
        #expect(!activity.startCalls.map(\.name.rawValue).contains(SharedConstants.reblockHeartbeatActivityName))
    }

    @Test func reconcileRegistersHeartbeatWhileUnblocksArePending() throws {
        let (service, activity, store) = makeService()
        store.timedUnblocks = try [TimedUnblockDTO(
            id: TimedUnblockService.mainID,
            selectionData: FamilyActivitySelection().toData(),
            endDate: .now.addingTimeInterval(.hours(1)),
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false
        )]

        service.reconcile(screenTimeService: FakeScreenTimeService())

        #expect(activity.startCalls.last?.name.rawValue == SharedConstants.reblockHeartbeatActivityName)
        #expect(activity.startCalls.last?.schedule == DeviceActivityScheduleFactory.heartbeat())
    }

    @Test func reconcileDropsUnblockThatExpiredWhileAppWasDeadAndReconciles() {
        let store = FakeSharedStore()
        store.timedUnblocks = [expiredMainDTO()]
        let screenTime = FakeScreenTimeService()

        let service = TimedUnblockService(
            activityCenter: FakeDeviceActivityCenter(),
            sharedStore: store,
            onExpiration: {}
        )

        service.reconcile(screenTimeService: screenTime)

        #expect(screenTime.reconcileCallCount == 1)
        #expect(store.timedUnblocks.isEmpty)
    }

    @Test func reconcileDropsExpiredGroupAndReconciles() throws {
        let store = FakeSharedStore()
        let groupId = UUID()
        store.timedUnblocks = try [TimedUnblockDTO(
            id: groupId.uuidString,
            selectionData: FamilyActivitySelection().toData(),
            endDate: Date.now.addingTimeInterval(-.minutes(1)),
            activityName: SharedConstants.groupTimedUnblockActivityName(for: groupId),
            isGroupUnblock: true
        )]
        let screenTime = FakeScreenTimeService()

        let service = TimedUnblockService(
            activityCenter: FakeDeviceActivityCenter(),
            sharedStore: store,
            onExpiration: {}
        )

        service.reconcile(screenTimeService: screenTime)

        #expect(screenTime.reconcileCallCount == 1)
        #expect(store.timedUnblocks.isEmpty)
    }

    @Test func reconcileSkipsExpiredGroupWhenMainStillActive() throws {
        let store = FakeSharedStore()
        let groupId = UUID()
        store.timedUnblocks = try [
            TimedUnblockDTO(
                id: TimedUnblockService.mainID,
                selectionData: FamilyActivitySelection().toData(),
                endDate: Date.now.addingTimeInterval(.minutes(30)),
                activityName: SharedConstants.mainTimedUnblockActivityName,
                isGroupUnblock: false
            ),
            TimedUnblockDTO(
                id: groupId.uuidString,
                selectionData: FamilyActivitySelection().toData(),
                endDate: Date.now.addingTimeInterval(-.minutes(1)),
                activityName: SharedConstants.groupTimedUnblockActivityName(for: groupId),
                isGroupUnblock: true
            ),
        ]
        let screenTime = FakeScreenTimeService()

        let service = TimedUnblockService(
            activityCenter: FakeDeviceActivityCenter(),
            sharedStore: store,
            onExpiration: {}
        )

        service.reconcile(screenTimeService: screenTime)

        #expect(!screenTime.blockCalled)
        #expect(service.isMainUnblockActive)
        #expect(store.timedUnblocks.map(\.id) == [TimedUnblockService.mainID])
    }

    @Test func reconcileLeavesActiveUnblockArmedWithoutReblocking() throws {
        let store = FakeSharedStore()
        store.timedUnblocks = try [TimedUnblockDTO(
            id: TimedUnblockService.mainID,
            selectionData: FamilyActivitySelection().toData(),
            endDate: Date.now.addingTimeInterval(.minutes(30)),
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false
        )]
        let screenTime = FakeScreenTimeService()

        let service = TimedUnblockService(
            activityCenter: FakeDeviceActivityCenter(),
            sharedStore: store,
            onExpiration: {}
        )

        service.reconcile(screenTimeService: screenTime)

        #expect(!screenTime.blockAllCalled)
        #expect(service.isMainUnblockActive)
        #expect(store.timedUnblocks.count == 1)
    }

    // MARK: - Multiple simultaneous group unblocks

    @discardableResult
    private func startGroup(
        _ service: TimedUnblockService,
        _ screenTime: FakeScreenTimeService,
        _ groupId: UUID,
        duration: TimedUnblockDuration = .fifteenMinutes
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
        service.cancelGroup(groupId: groupA)

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

        service.cancelGroup(groupId: groupA)

        #expect(service.groupUnblockEndDate(groupId: groupB) == endBBefore)
    }

    // MARK: - Custom domains

    @Test func startMainPersistsCustomDomainsInDTO() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            customDomains: ["reddit.com"],
            screenTimeService: screenTime
        )

        #expect(store.timedUnblocks.first?.customDomains == ["reddit.com"])
    }

    /// Home's "Unblock All" with a default duration skips the sheet; it once dropped custom domains,
    /// so websites never reblocked at expiry. Both Home paths now go through this overload.
    @Test func startMainFromModelsPersistsCustomDomainsWhenEnabled() throws {
        let (service, _, store) = makeService()
        let settings = Settings()
        settings.enableCustomDomains = true
        let mainSelection = SelectedApps(selection: FamilyActivitySelection(), customDomains: ["reddit.com"])

        try service.startMain(
            duration: .oneHour,
            mainSelection: mainSelection,
            settings: settings,
            screenTimeService: FakeScreenTimeService()
        )

        #expect(store.timedUnblocks.first?.customDomains == ["reddit.com"])
    }

    @Test func startMainFromModelsOmitsCustomDomainsWhenFeatureDisabled() throws {
        let (service, _, store) = makeService()
        let settings = Settings()
        settings.enableCustomDomains = false
        let mainSelection = SelectedApps(selection: FamilyActivitySelection(), customDomains: ["reddit.com"])

        try service.startMain(
            duration: .oneHour,
            mainSelection: mainSelection,
            settings: settings,
            screenTimeService: FakeScreenTimeService()
        )

        #expect(store.timedUnblocks.first?.customDomains == [])
    }

    @Test func startMainFromModelsCarriesPreventAppDeleteSetting() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let settings = Settings()
        settings.blockAllPreventsAppDelete = true

        try service.startMain(
            duration: .oneHour,
            mainSelection: SelectedApps(selection: FamilyActivitySelection()),
            settings: settings,
            screenTimeService: screenTime
        )

        #expect(store.timedUnblocks.first?.blockAllPreventsAppDelete == true)
    }

    @Test func editingGroupDomainsDuringUnblockUpdatesReblockPayload() throws {
        let (service, _, store) = makeService()
        let screenTime = FakeScreenTimeService()
        let groupId = UUID()

        // Group timed-unblock starts while the group blocks reddit.com.
        try service.startGroup(
            duration: .fifteenMinutes,
            groupId: groupId,
            selection: FamilyActivitySelection(),
            customDomains: ["reddit.com"],
            screenTimeService: screenTime
        )
        let endDate = service.groupUnblockEndDate(groupId: groupId)

        // User edits the group mid-unblock and removes the domain.
        service.updateGroupSelection(groupId: groupId, selection: FamilyActivitySelection(), customDomains: [])

        let dto = store.timedUnblocks.first { $0.id == groupId.uuidString }
        #expect(dto?.customDomains == [], "Reblock payload reflects the removed domain")
        #expect(dto?.endDate == endDate, "Editing must not disturb the unblock's expiry")
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

    @Test func maximumWindowCrossingMidnightIsPreservedExactly() {
        let start = date(hour: 22, minute: 0)
        let end = start.addingTimeInterval(TimeInterval(TimedUnblockDuration.maximumSeconds))
        let schedule = DeviceActivityScheduleFactory.window(from: start, to: end, calendar: Self.utc)

        #expect(intervalSeconds(schedule) == TimeInterval(TimedUnblockDuration.maximumSeconds))
        #expect(schedule.intervalEnd.day == 2)
        #expect(schedule.intervalEnd.hour == 21)
        #expect(schedule.intervalEnd.minute == 55)
        #expect(schedule.repeats == false)
    }

    @Test func longerWindowIsPreservedExactly() {
        let start = date(hour: 10, minute: 0)
        let schedule = DeviceActivityScheduleFactory.window(
            from: start, to: start.addingTimeInterval(.hours(1)), calendar: Self.utc
        )
        #expect(intervalSeconds(schedule) == .hours(1))
    }
}
