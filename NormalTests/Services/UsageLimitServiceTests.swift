import DeviceActivity
import FamilyControls
import Foundation
import Testing

@testable import Normal

@MainActor
struct UsageLimitServiceTests {
    /// Every test pins its own instant. The production APIs all accept an
    /// injected date, so nothing here should consult the wall clock.
    private let day = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let config = UsageLimitConfig()

    private struct Harness {
        let service: UsageLimitService
        let center: FakeDeviceActivityCenter
        let store: FakeSharedStore
        let ledger: InMemoryUsageLimitLedger
        let shield: InMemoryDailyLimitShield
    }

    private func makeService(ledgerDate: Date? = nil) -> Harness {
        let center = FakeDeviceActivityCenter()
        let store = FakeSharedStore()
        let ledger = InMemoryUsageLimitLedger(date: ledgerDate)
        let shield = InMemoryDailyLimitShield()
        let service = UsageLimitService(
            activityCenter: center,
            sharedStore: store,
            ledger: ledger,
            limitShield: shield
        )
        return Harness(service: service, center: center, store: store, ledger: ledger, shield: shield)
    }

    /// `FamilyActivitySelection` cannot be populated with real tokens in a unit
    /// test, so DTOs are built directly where a non-empty selection matters.
    private func dto(id: UUID = UUID(), minutes: Int) throws -> UsageLimitDTO {
        try UsageLimitDTO(
            id: id,
            selectionData: FamilyActivitySelection().toData(),
            minutesPerDay: minutes
        )
    }

    private var usageActivity: DeviceActivityName {
        DeviceActivityName(SharedConstants.usageLimitsActivityName)
    }

    // MARK: - Event specs

    @Test func eventSpecsAreDerivedOnePerLimit() throws {
        let first = try dto(minutes: 60)
        let second = try dto(minutes: 20)

        let specs = UsageLimitService.eventSpecs(for: [first, second], period: config.period, on: day)

        #expect(specs.count == 2)
        #expect(specs.map(\.minutes).sorted() == [20, 60])
    }

    @Test func eventNamesRoundTripBackToTheirLimit() throws {
        let limit = try dto(minutes: 60)

        let spec = try #require(UsageLimitService.eventSpecs(for: [limit], period: config.period, on: day).first)

        #expect(spec.eventName == SharedConstants.usageLimitEventName(for: limit.id))
        #expect(SharedConstants.usageLimitID(fromEventName: spec.eventName) == limit.id)
    }

    /// A selection with no tokens has nothing to meter, so it must not be
    /// armed — otherwise the threshold never fires and the limit looks active
    /// while doing nothing.
    @Test func aLimitWithAnEmptySelectionIsNotArmable() throws {
        let spec = try #require(try UsageLimitService.eventSpecs(for: [dto(minutes: 60)], period: config.period, on: day).first)

        #expect(spec.isArmable == false)
    }

    @Test func aLimitWithUndecodableSelectionIsDropped() {
        let broken = UsageLimitDTO(
            id: UUID(),
            selectionData: Data([0xFF, 0xFE]),
            minutesPerDay: 60
        )

        #expect(UsageLimitService.eventSpecs(for: [broken], period: config.period, on: day).isEmpty)
    }

    @Test func aLimitCreatedTodayCountsOnlyTimeAfterItIsRegistered() throws {
        var limit = try dto(minutes: 60)
        limit.createdAt = day

        let spec = try #require(UsageLimitService.eventSpecs(for: [limit], period: config.period, on: day).first)

        #expect(spec.includesPastActivity == false)
        #expect(spec.event.includesPastActivity == false)
    }

    @Test func aLimitCreatedBeforeTodaysResetCountsTheWholeDay() throws {
        var limit = try dto(minutes: 60)
        limit.createdAt = day - .days(1)

        let spec = try #require(UsageLimitService.eventSpecs(for: [limit], period: config.period, on: day).first)

        #expect(spec.includesPastActivity)
        #expect(spec.event.includesPastActivity)
    }

    @Test func aLimitSavedBeforeCreationDatesExistedCountsTheWholeDay() throws {
        let spec = try #require(try UsageLimitService.eventSpecs(for: [dto(minutes: 60)], period: config.period, on: day).first)

        #expect(spec.includesPastActivity)
    }

    @Test func aNewLimitCountsTheWholeDayFromTheNextDaysRegistration() throws {
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 60, createdAt: day)

        h.service.registerAll([limit], config: config, on: day)
        h.service.registerAll([limit], config: config, on: day + .days(1))

        let flags = h.center.startCalls.compactMap { $0.events.values.first?.includesPastActivity }
        #expect(flags == [false, true])
    }

    @Test func theEditorSaysWhetherTimeUsedEarlierTodayCounts() {
        let h = makeService()
        let createdToday = UsageLimit(minutesPerDay: 60, createdAt: day)
        let createdYesterday = UsageLimit(minutesPerDay: 60, createdAt: day - .days(1))

        #expect(h.service.countsTimeUsedEarlierToday(by: nil, on: day) == false)
        #expect(h.service.countsTimeUsedEarlierToday(by: createdToday, on: day) == false)
        #expect(h.service.countsTimeUsedEarlierToday(by: createdYesterday, on: day))
    }

    // MARK: - The daily schedule

    @Test func aMidnightResetSpansOneCalendarDay() {
        let schedule = DeviceActivityScheduleFactory.daily(
            resetMinutes: 0,
            warningMinutes: UsageLimitService.warningMinutes
        )

        #expect(schedule.intervalStart.hour == 0)
        #expect(schedule.intervalStart.minute == 0)
        #expect(schedule.intervalEnd.hour == 23)
        #expect(schedule.intervalEnd.minute == 59)
        #expect(schedule.intervalEnd.second == 59)
        #expect(schedule.repeats)
        #expect(schedule.warningTime?.minute == UsageLimitService.warningMinutes)
    }

    @Test func aLaterResetWrapsPastMidnight() {
        let schedule = DeviceActivityScheduleFactory.daily(resetMinutes: 4 * 60 + 30, warningMinutes: 3)

        #expect(schedule.intervalStart.hour == 4)
        #expect(schedule.intervalStart.minute == 30)
        #expect(schedule.intervalEnd.hour == 4)
        #expect(schedule.intervalEnd.minute == 29)
        #expect(schedule.intervalEnd.second == 59)
        #expect(schedule.repeats)
    }

    // MARK: - Registration

    @Test func registeringWithNoLimitsStopsTheUsageActivityAndStartsNothing() {
        let h = makeService()

        h.service.registerAll([], config: config, on: day)

        #expect(h.store.usageLimits.isEmpty)
        #expect(h.center.startCalls.isEmpty)
        #expect(h.center.stopCalls == [[usageActivity]])
    }

    @Test func registeringMirrorsLimitsAndConfigToTheAppGroup() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 90)
        let config = UsageLimitConfig(resetMinutes: 240, preventsAppDelete: true)

        h.service.registerAll([limit], config: config, on: day)

        #expect(h.store.usageLimits.count == 1)
        #expect(h.store.usageLimits.first?.minutesPerDay == 90)
        #expect(h.store.usageLimits.first?.id == limit.id)
        #expect(h.store.usageLimitConfig == config)
    }

    // MARK: - Registration is idempotent

    /// `registerAll` runs on every foreground. Tearing monitoring down and
    /// re-arming it each time risks disturbing threshold accumulation, so an
    /// unchanged registration must be skipped entirely.
    @Test func reRegisteringAnUnchangedSetDoesNotTouchMonitoring() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 60)

        h.service.registerAll([limit], config: config, on: day)
        let stopsAfterFirst = h.center.stopCalls.count

        h.service.registerAll([limit], config: config, on: day)

        #expect(h.center.stopCalls.count == stopsAfterFirst)
    }

    @Test func reRegisteringAnUnchangedArmedSetDoesNotTouchMonitoring() {
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 60)

        h.service.registerAll([limit], config: config, on: day)
        h.service.registerAll([limit], config: config, on: day)

        #expect(h.center.startCalls.count == 1)
        #expect(h.center.stopCalls.count == 1)
    }

    @Test(arguments: [UsageLimitState.warning, .reached])
    func acceptsAnImmediateCallbackForAnExistingDailyLimit(_ state: UsageLimitState) throws {
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 5, createdAt: day - .days(1))
        let restarted = Calendar.current.startOfDay(for: day) + .hours(22)
        h.service.registerAll([limit], config: config, on: restarted)
        let event = try #require(h.center.startCalls.last?.events.first)
        try #require(event.value.includesPastActivity)
        h.store.saveUsageLimitsIntervalStart(restarted)

        let delivered = restarted + 0.049
        if state == .reached {
            h.store.enforceUsageThreshold(eventName: event.key.rawValue, on: delivered, apply: h.shield.apply)
        } else {
            _ = h.store.recordUsageCallback(state, eventName: event.key.rawValue, on: delivered)
        }

        #expect(h.service.state(for: limit, on: delivered) == state)
        #expect(h.shield.shieldedLimitIDs == (state == .reached ? [limit.id] : []))
    }

    @Test(arguments: [UsageLimitState.warning, .reached])
    func rejectsSpuriousCallbacksAfterCreationOrReset(_ state: UsageLimitState) {
        let midnight = Calendar.current.startOfDay(for: day)
        let created = midnight + .hours(10)
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 30, createdAt: created)
        let event = SharedConstants.usageLimitEventName(for: limit.id)
        let tomorrow = config.period.nextReset(after: created)

        for start in [created, tomorrow] {
            h.service.registerAll([limit], config: config, on: start)
            h.store.resetUsageDayIfStale(on: start)
            let delivered = start + 15
            #expect(h.store.recordUsageCallback(state, eventName: event, on: delivered) == nil)
            #expect(h.service.state(for: limit, on: delivered) == .under)
            #expect(h.store.reachedUsageLimits(on: delivered).isEmpty)
        }
    }

    @Test func acceptsADayOneThresholdWithinMeteringJitter() {
        let midnight = Calendar.current.startOfDay(for: day)
        let created = midnight + .hours(10)
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 5, createdAt: created)
        let event = SharedConstants.usageLimitEventName(for: limit.id)
        h.service.registerAll([limit], config: config, on: created)
        h.store.saveUsageLimitsIntervalStart(created)

        let delivered = created + .minutes(5) - 1
        h.store.enforceUsageThreshold(eventName: event, on: delivered, apply: h.shield.apply)

        #expect(h.service.state(for: limit, on: delivered) == .reached)
        #expect(h.shield.shieldedLimitIDs == [limit.id])
    }

    @Test func rejectsADayOneFalseFireRightAfterMidDayReRegistration() {
        let midnight = Calendar.current.startOfDay(for: day)
        let created = midnight + .hours(10)
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 5, createdAt: created)
        let event = SharedConstants.usageLimitEventName(for: limit.id)
        h.service.registerAll([limit], config: config, on: created)

        let reRegistered = created + .minutes(15)
        h.center.stopMonitoring([usageActivity])
        h.service.registerAll([limit], config: config, on: reRegistered)
        h.store.saveUsageLimitsIntervalStart(reRegistered)
        h.store.enforceUsageThreshold(eventName: event, on: reRegistered + 0.05, apply: h.shield.apply)

        #expect(h.service.state(for: limit, on: reRegistered + 0.05) == .under)
        #expect(h.shield.shieldedLimitIDs.isEmpty)
    }

    @Test func acceptsNonMidnightResetDayTwoHourlyBucketCallback() {
        let resetConfig = UsageLimitConfig(resetMinutes: 4 * 60 + 30)
        let midnight = Calendar.current.startOfDay(for: day)
        let created = midnight + .hours(4) + .minutes(25)
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 30, createdAt: created)
        let event = SharedConstants.usageLimitEventName(for: limit.id)
        let afterReset = midnight + .hours(4) + .minutes(40)
        h.service.registerAll([limit], config: resetConfig, on: afterReset)

        h.store.enforceUsageThreshold(eventName: event, on: afterReset, apply: h.shield.apply)

        #expect(h.service.state(for: limit, on: afterReset) == .reached)
        #expect(h.shield.shieldedLimitIDs == [limit.id])
    }

    @Test func rejectsAFalseFireWhenNormalRegistersAtTheReset() {
        let resetConfig = UsageLimitConfig(resetMinutes: 4 * 60 + 30)
        let midnight = Calendar.current.startOfDay(for: day)
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 30, createdAt: day - .days(10))
        let event = SharedConstants.usageLimitEventName(for: limit.id)
        let reset = midnight + .hours(4) + .minutes(30)

        h.service.registerAll([limit], config: resetConfig, on: reset + 2)
        h.store.resetUsageDayIfStale(on: reset + 2)
        h.store.saveUsageLimitsIntervalStart(reset + 2.1)
        h.store.enforceUsageThreshold(eventName: event, on: reset + 3, apply: h.shield.apply)

        #expect(h.service.state(for: limit, on: reset + 3) == .under)
        #expect(h.shield.shieldedLimitIDs.isEmpty)
    }

    @Test func rejectsAFalseFireWhenMonitoringRestartsWithoutNormalRegistering() {
        let midnight = Calendar.current.startOfDay(for: day)
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 30, createdAt: day - .days(10))
        let event = SharedConstants.usageLimitEventName(for: limit.id)
        h.service.registerAll([limit], config: config, on: midnight + .hours(9))

        let restarted = midnight + .hours(15)
        h.store.saveUsageLimitsIntervalStart(restarted)
        h.store.enforceUsageThreshold(eventName: event, on: restarted + 0.1, apply: h.shield.apply)

        #expect(h.service.state(for: limit, on: restarted + 0.1) == .under)
        #expect(h.shield.shieldedLimitIDs.isEmpty)
    }

    @Test func ignoresCallbacksDuringEmergencyOverride() {
        let midnight = Calendar.current.startOfDay(for: day)
        let now = midnight + .hours(12)
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 5, createdAt: day - .days(1))
        let event = SharedConstants.usageLimitEventName(for: limit.id)
        h.service.registerAll([limit], config: config, on: now)
        h.service.overrideToday(on: now)

        h.store.enforceUsageThreshold(eventName: event, on: now + 1, apply: h.shield.apply)

        #expect(h.service.state(for: limit, on: now + 1) == .under)
        #expect(h.shield.shieldedLimitIDs.isEmpty)
    }

    @Test func anUnchangedSetIsRegisteredAgainWhenIOSNoLongerListsIt() {
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 60)
        h.service.registerAll([limit], config: config, on: day)
        h.center.stopMonitoring([usageActivity])

        h.service.registerAll([limit], config: config, on: day)

        #expect(h.center.startCalls.count == 2)
        #expect(h.center.monitoredActivityNames.contains(usageActivity.rawValue))
    }

    @Test func tooManyActivitiesIsReportedUntilRegistrationSucceeds() {
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 60)
        h.center.startError = DeviceActivityCenter.MonitoringError.excessiveActivities

        h.service.registerAll([limit], config: config, on: day)
        #expect(h.service.registrationFailure == .tooManyActivities)

        h.center.startError = nil
        h.service.registerAll([limit], config: config, on: day)
        #expect(h.service.registrationFailure == nil)
        #expect(h.center.monitoredActivityNames.contains(usageActivity.rawValue))
    }

    @Test func aLimitAddedWhenSchedulesFillEverySlotIsReportedUntilOneIsFreed() {
        let center = FakeDeviceActivityCenter()
        center.activityLimit = 20
        let store = FakeSharedStore()
        let schedules = ScheduleService(activityCenter: center, sharedStore: store, clock: { day })
        let limits = UsageLimitService(
            activityCenter: center,
            sharedStore: store,
            ledger: InMemoryUsageLimitLedger(date: nil),
            limitShield: InMemoryDailyLimitShield()
        )
        let nineteen = (0..<19).map { _ in
            BlockSchedule(
                name: "Work",
                selection: FamilyActivitySelection(),
                startHour: 9, startMinute: 0,
                durationMinutes: 60,
                weekdays: [2, 3, 4, 5, 6],
                shouldBlock: true,
                isTimed: true,
                isEnabled: true
            )
        }
        schedules.registerAll(nineteen, screenTimeService: FakeScreenTimeService())
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 30, createdAt: day)

        limits.registerAll([limit], config: config, on: day)
        #expect(!center.monitoredActivityNames.contains(usageActivity.rawValue))
        #expect(limits.registrationFailure == .tooManyActivities)

        nineteen[0].isEnabled = false
        schedules.registerAll(nineteen, screenTimeService: FakeScreenTimeService())
        limits.registerAll([limit], config: config, on: day)
        #expect(center.monitoredActivityNames.contains(usageActivity.rawValue))
        #expect(limits.registrationFailure == nil)
    }

    @Test func otherRegistrationErrorsAreReportedAsFailed() {
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 60)
        h.center.startError = DeviceActivityCenter.MonitoringError.unauthorized

        h.service.registerAll([limit], config: config, on: day)

        #expect(h.service.registrationFailure == .failed)
    }

    @Test func removingEveryLimitClearsARegistrationFailure() {
        let h = makeService()
        let limit = UsageLimit(selection: TokenFixtures.selection(apps: [1]), minutesPerDay: 60)
        h.center.startError = DeviceActivityCenter.MonitoringError.excessiveActivities
        h.service.registerAll([limit], config: config, on: day)

        h.service.registerAll([], config: config, on: day)

        #expect(h.service.registrationFailure == nil)
    }

    @Test func changingALimitReRegisters() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 60)

        h.service.registerAll([limit], config: config, on: day)
        let stopsAfterFirst = h.center.stopCalls.count

        limit.minutesPerDay = 30
        h.service.registerAll([limit], config: config, on: day)

        #expect(h.center.stopCalls.count > stopsAfterFirst)
    }

    @Test func changingTheResetTimeReRegisters() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 60)

        h.service.registerAll([limit], config: config, on: day)
        let stopsAfterFirst = h.center.stopCalls.count

        h.service.registerAll([limit], config: UsageLimitConfig(resetMinutes: 240), on: day)

        #expect(h.center.stopCalls.count > stopsAfterFirst)
    }

    @Test func aNewDayReRegisters() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 60)

        h.service.registerAll([limit], config: config, on: day)
        let stopsAfterFirst = h.center.stopCalls.count

        h.service.registerAll([limit], config: config, on: day + .days(1))

        #expect(h.center.stopCalls.count > stopsAfterFirst)
    }

    /// Re-registering must never hand back an allowance already spent.
    @Test func reRegisteringDoesNotRefillASpentAllowance() {
        let h = makeService()
        let total = UsageLimit(minutesPerDay: 30)
        h.service.registerAll([total], config: config, on: day)
        h.store.recordUsageState(.reached, for: total.id, on: day)

        h.service.registerAll([total], config: config, on: day)
        h.service.registerAll([total], config: config, on: day + .hours(2))

        #expect(h.service.state(for: total, on: day + .hours(2)) == .reached)
    }

    @Test func aSpentLimitIsShieldedInTheLimitStore() {
        let h = makeService()
        let spent = UsageLimit(minutesPerDay: 30)
        let other = UsageLimit(minutesPerDay: 60)
        h.service.registerAll([spent, other], config: config, on: day)
        h.store.recordUsageState(.reached, for: spent.id, on: day)

        h.service.registerAll([spent, other], config: config, on: day)

        #expect(h.shield.shieldedLimitIDs == [spent.id])
    }

    @Test func theLimitStoreLiftsOnceThePeriodResets() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        h.service.registerAll([limit], config: config, on: day)
        h.store.recordUsageState(.reached, for: limit.id, on: day)

        h.service.registerAll([limit], config: config, on: day + .days(1))

        #expect(h.shield.shieldedLimitIDs.isEmpty)
    }

    @Test func movingTheResetPastTheCurrentTimeLiftsASpentLimitAtTheNewReset() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        let midnight = Calendar.current.startOfDay(for: day)
        let spentAt = midnight + .hours(15)
        h.service.registerAll([limit], config: config, on: spentAt)
        h.store.recordUsageState(.reached, for: limit.id, on: spentAt)

        let later = UsageLimitConfig(resetMinutes: 16 * 60)
        h.service.registerAll([limit], config: later, on: spentAt + .minutes(30))
        #expect(h.shield.shieldedLimitIDs == [limit.id])

        h.service.registerAll([limit], config: later, on: midnight + .hours(16) + .minutes(1))
        #expect(h.shield.shieldedLimitIDs.isEmpty)
    }

    @Test func deletingASpentLimitLiftsItsShield() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        h.service.registerAll([limit], config: config, on: day)
        h.store.recordUsageState(.reached, for: limit.id, on: day)
        h.service.registerAll([limit], config: config, on: day)

        h.service.registerAll([], config: config, on: day)

        #expect(h.shield.shieldedLimitIDs.isEmpty)
    }

    @Test func aSpentLimitKeepsTheAppUndeletableWhenTheSettingIsOn() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        let config = UsageLimitConfig(preventsAppDelete: true)
        h.service.registerAll([limit], config: config, on: day)
        #expect(h.shield.preventsAppDelete == false)

        h.store.recordUsageState(.reached, for: limit.id, on: day)
        h.service.registerAll([limit], config: config, on: day)

        #expect(h.shield.preventsAppDelete)
    }

    @Test func aSpentLimitLeavesTheAppDeletableWhenTheSettingIsOff() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        h.service.registerAll([limit], config: UsageLimitConfig(preventsAppDelete: false), on: day)
        h.store.recordUsageState(.reached, for: limit.id, on: day)

        h.service.registerAll([limit], config: UsageLimitConfig(preventsAppDelete: false), on: day)

        #expect(h.shield.preventsAppDelete == false)
    }

    @Test func aSpentLimitStaysSpentUntilTheConfiguredReset() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        let config = UsageLimitConfig(resetMinutes: 4 * 60)
        h.service.registerAll([limit], config: config, on: day)
        h.store.recordUsageState(.reached, for: limit.id, on: day)

        let reset = config.period.nextReset(after: day)

        #expect(h.service.nextReset(after: day) == reset)
        #expect(h.service.state(for: limit, on: reset - .minutes(1)) == .reached)
        #expect(h.service.state(for: limit, on: reset + .minutes(1)) == .under)
    }

    @Test func stateDefaultsToUnderAndFollowsWhatTheMonitorWrote() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)

        #expect(h.service.state(for: limit, on: day) == .under)

        h.store.recordUsageState(.warning, for: limit.id, on: day)
        #expect(h.service.state(for: limit, on: day) == .warning)

        h.store.recordUsageState(.reached, for: limit.id, on: day)
        #expect(h.service.state(for: limit, on: day) == .reached)
    }

    @Test func statesForAListMatchTheSingleLookups() {
        let h = makeService()
        let spent = UsageLimit(minutesPerDay: 30)
        let fresh = UsageLimit(minutesPerDay: 60)
        h.store.recordUsageState(.reached, for: spent.id, on: day)

        let states = h.service.states(for: [spent, fresh], on: day)

        #expect(states[spent.id] == .reached)
        #expect(states[fresh.id] == .under)
    }

    @Test func aLateWarningCannotUndoAReachedLimit() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)

        h.store.recordUsageState(.reached, for: limit.id, on: day)
        h.store.recordUsageState(.warning, for: limit.id, on: day)

        #expect(h.service.state(for: limit, on: day) == .reached)
    }

    @Test func yesterdaysRecordDoesNotLeakIntoToday() {
        let h = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        let yesterday = day - .days(1)

        h.store.recordUsageState(.reached, for: limit.id, on: yesterday)

        #expect(h.service.state(for: limit, on: yesterday) == .reached)
        #expect(h.service.state(for: limit, on: day) == .under)
    }

    @Test func clearStateDropsTheRecordAndLiftsOnlyThatLimit() {
        let h = makeService()
        let raised = UsageLimit(minutesPerDay: 30)
        let other = UsageLimit(minutesPerDay: 30)
        h.service.registerAll([raised, other], config: config, on: day)
        h.store.recordUsageState(.reached, for: raised.id, on: day)
        h.store.recordUsageState(.reached, for: other.id, on: day)

        h.service.clearState(for: raised, on: day)

        #expect(h.service.state(for: raised, on: day) == .under)
        #expect(h.shield.shieldedLimitIDs == [other.id])
    }

    // MARK: - Emergency override

    @Test func emergencyOverrideLiftsEveryLimitForThePeriod() {
        let h = makeService()
        let total = UsageLimit(minutesPerDay: 30)
        h.service.registerAll([total], config: config, on: day)
        h.store.recordUsageState(.reached, for: total.id, on: day)
        h.service.registerAll([total], config: config, on: day)

        h.service.overrideToday(on: day)

        #expect(h.service.state(for: total, on: day) == .under)
        #expect(h.service.isDayOverridden(on: day))
        #expect(h.shield.shieldedLimitIDs.isEmpty)
    }

    @Test func emergencyOverrideKeepsMonitoringArmed() {
        let h = makeService()
        let total = UsageLimit(minutesPerDay: 30)
        h.service.registerAll([total], config: config, on: day)
        let stopsBefore = h.center.stopCalls.count

        h.service.overrideToday(on: day)
        h.service.registerAll([total], config: config, on: day)

        #expect(h.center.stopCalls.count == stopsBefore)
    }

    @Test func theOverrideExpiresWithThePeriod() {
        let h = makeService()
        h.store.overrideUsageDay(on: day)

        #expect(h.service.isDayOverridden(on: day))
        #expect(h.service.isDayOverridden(on: day + .days(2)) == false)
    }

    @Test func theResetAnchorIsReadFromTheLedgerOnLaunch() {
        let stored = Date(timeIntervalSinceReferenceDate: 500_000)
        let h = makeService(ledgerDate: stored)

        #expect(h.service.resetAnchor == stored)
        #expect(h.service.resetLockState(now: stored + .days(1)) == .locked(until: stored + .days(7)))
    }

    @Test func committingAResetChangeWritesThroughToTheLedger() {
        let h = makeService()
        let now = Date(timeIntervalSinceReferenceDate: 700_000)

        h.service.commitResetChange(.cooldownElapsed, now: now)

        #expect(h.ledger.loadLastLoosened() == now)
        #expect(h.service.resetAnchor == now)
    }

    @Test func aResetChangeInsideGraceLeavesTheLedgerUntouched() {
        let stored = Date(timeIntervalSinceReferenceDate: 500_000)
        let h = makeService(ledgerDate: stored)

        h.service.commitResetChange(.grace, now: stored + .minutes(5))

        #expect(h.ledger.loadLastLoosened() == stored)
    }

    @Test func resetChangesFollowTheStoredAnchor() {
        let stored = Date(timeIntervalSinceReferenceDate: 500_000)
        let h = makeService(ledgerDate: stored)

        #expect(h.service.decideResetChange(now: stored + .minutes(5)) == .allowed(.grace))
        #expect(h.service.decideResetChange(now: stored + .days(2)) == .locked(until: stored + .days(7)))
        #expect(h.service.decideResetChange(now: stored + .days(7)) == .allowed(.cooldownElapsed))
    }

    @Test func theKeychainLedgerSurvivesARelaunch() {
        let item = InMemoryKeychainItem()
        let stored = Date(timeIntervalSinceReferenceDate: 500_000)
        KeychainUsageLimitLedger(item: item).saveLastLoosened(stored)

        let relaunched = UsageLimitService(
            activityCenter: FakeDeviceActivityCenter(),
            sharedStore: FakeSharedStore(),
            ledger: KeychainUsageLimitLedger(item: item),
            limitShield: InMemoryDailyLimitShield()
        )

        #expect(relaunched.decideResetChange(now: stored + .days(2)) == .locked(until: stored + .days(7)))
    }
}

private final class InMemoryKeychainItem: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    func loadData() -> Data? {
        lock.withLock { data }
    }

    func saveData(_ data: Data) {
        lock.withLock { self.data = data }
    }

    func delete() {
        lock.withLock { data = nil }
    }
}
