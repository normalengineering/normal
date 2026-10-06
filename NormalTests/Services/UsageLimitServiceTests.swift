import DeviceActivity
import FamilyControls
import Foundation
@testable import Normal
import Testing

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

        let specs = UsageLimitService.eventSpecs(for: [first, second])

        #expect(specs.count == 2)
        #expect(specs.map(\.minutes).sorted() == [20, 60])
    }

    @Test func eventNamesRoundTripBackToTheirLimit() throws {
        let limit = try dto(minutes: 60)

        let spec = try #require(UsageLimitService.eventSpecs(for: [limit]).first)

        #expect(spec.eventName == SharedConstants.usageLimitEventName(for: limit.id))
        #expect(SharedConstants.usageLimitID(fromEventName: spec.eventName) == limit.id)
    }

    /// A selection with no tokens has nothing to meter, so it must not be
    /// armed — otherwise the threshold never fires and the limit looks active
    /// while doing nothing.
    @Test func aLimitWithAnEmptySelectionIsNotArmable() throws {
        let spec = try #require(try UsageLimitService.eventSpecs(for: [dto(minutes: 60)]).first)

        #expect(spec.isArmable == false)
    }

    @Test func aLimitWithUndecodableSelectionIsDropped() {
        let broken = UsageLimitDTO(
            id: UUID(),
            selectionData: Data([0xFF, 0xFE]),
            minutesPerDay: 60
        )

        #expect(UsageLimitService.eventSpecs(for: [broken]).isEmpty)
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
}
