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

    private func makeService(
        ledgerDate: Date? = nil
    ) -> (UsageLimitService, FakeDeviceActivityCenter, FakeSharedStore, InMemoryUsageLimitLedger) {
        let center = FakeDeviceActivityCenter()
        let store = FakeSharedStore()
        let ledger = InMemoryUsageLimitLedger(date: ledgerDate)
        let service = UsageLimitService(activityCenter: center, sharedStore: store, ledger: ledger)
        return (service, center, store, ledger)
    }

    /// `FamilyActivitySelection` cannot be populated with real tokens in a unit
    /// test, so DTOs are built directly where a non-empty selection matters.
    private func dto(id: UUID = UUID(), minutes: Int) throws -> UsageLimitDTO {
        UsageLimitDTO(
            id: id,
            selectionData: try FamilyActivitySelection().toData(),
            minutesPerDay: minutes
        )
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
        let spec = try #require(UsageLimitService.eventSpecs(for: [try dto(minutes: 60)]).first)

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

    @Test func theDailyScheduleSpansAWholeRepeatingDay() {
        let schedule = DeviceActivityScheduleFactory.daily(warningMinutes: UsageLimitService.warningMinutes)

        #expect(schedule.intervalStart.hour == 0)
        #expect(schedule.intervalStart.minute == 0)
        #expect(schedule.intervalEnd.hour == 23)
        #expect(schedule.intervalEnd.minute == 59)
        #expect(schedule.repeats)
        #expect(schedule.warningTime?.minute == UsageLimitService.warningMinutes)
    }

    /// The warning has to land before the shortest allowance is spent, or a
    /// minimum-length limit reads "Almost Up" from the first minute.
    @Test func theWarningFiresInsideTheShortestAllowedLimit() {
        #expect(UsageLimitService.warningMinutes < UsageLimit.minimumMinutes)
    }

    // MARK: - Registration

    @Test func registeringWithNoLimitsStopsTheUsageActivityAndStartsNothing() {
        let (service, center, store, _) = makeService()

        service.registerAll([], on: day)

        #expect(store.usageLimits.isEmpty)
        #expect(center.startCalls.isEmpty)
        #expect(center.stopCalls == [[DeviceActivityName(SharedConstants.usageLimitsActivityName)]])
    }

    @Test func registeringMirrorsLimitsToTheAppGroup() {
        let (service, _, store, _) = makeService()
        let limit = UsageLimit(minutesPerDay: 90)

        service.registerAll([limit], on: day)

        #expect(store.usageLimits.count == 1)
        #expect(store.usageLimits.first?.minutesPerDay == 90)
        #expect(store.usageLimits.first?.id == limit.id)
    }

    // MARK: - Registration is idempotent

    /// `registerAll` runs on every foreground. Tearing monitoring down and
    /// re-arming it each time risks disturbing threshold accumulation, so an
    /// unchanged registration must be skipped entirely.
    @Test func reRegisteringAnUnchangedSetDoesNotTouchMonitoring() {
        let (service, center, _, _) = makeService()
        let limit = UsageLimit(minutesPerDay: 60)

        service.registerAll([limit], on: day)
        let stopsAfterFirst = center.stopCalls.count

        service.registerAll([limit], on: day)

        #expect(center.stopCalls.count == stopsAfterFirst)
    }

    @Test func changingALimitReRegisters() {
        let (service, center, _, _) = makeService()
        let limit = UsageLimit(minutesPerDay: 60)

        service.registerAll([limit], on: day)
        let stopsAfterFirst = center.stopCalls.count

        limit.minutesPerDay = 30
        service.registerAll([limit], on: day)

        #expect(center.stopCalls.count > stopsAfterFirst)
    }

    /// The day is part of the fingerprint so monitoring is re-armed at least
    /// once per day even if the limits never change.
    @Test func aNewDayReRegisters() {
        let (service, center, _, _) = makeService()
        let limit = UsageLimit(minutesPerDay: 60)

        service.registerAll([limit], on: day)
        let stopsAfterFirst = center.stopCalls.count

        service.registerAll([limit], on: day + .days(1))

        #expect(center.stopCalls.count > stopsAfterFirst)
    }

    /// Re-registering must never hand back an allowance already spent.
    @Test func reRegisteringDoesNotRefillASpentAllowance() {
        let (service, _, store, _) = makeService()
        let total = UsageLimit(minutesPerDay: 30)
        service.registerAll([total], on: day)
        store.recordUsageState(.reached, for: total.id, on: day)

        service.registerAll([total], on: day)
        service.registerAll([total], on: day + .hours(2))

        #expect(service.state(for: total, on: day + .hours(2)) == .reached)
    }

    // MARK: - Today's state

    @Test func stateDefaultsToUnderAndFollowsWhatTheMonitorWrote() {
        let (service, _, store, _) = makeService()
        let limit = UsageLimit(minutesPerDay: 30)

        #expect(service.state(for: limit, on: day) == .under)

        store.recordUsageState(.warning, for: limit.id, on: day)
        #expect(service.state(for: limit, on: day) == .warning)

        store.recordUsageState(.reached, for: limit.id, on: day)
        #expect(service.state(for: limit, on: day) == .reached)
    }

    @Test func aLateWarningCannotUndoAReachedLimit() {
        let (service, _, store, _) = makeService()
        let limit = UsageLimit(minutesPerDay: 30)

        store.recordUsageState(.reached, for: limit.id, on: day)
        store.recordUsageState(.warning, for: limit.id, on: day)

        #expect(service.state(for: limit, on: day) == .reached)
    }

    @Test func yesterdaysRecordDoesNotLeakIntoToday() {
        let (service, _, store, _) = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        let yesterday = day - .days(1)

        store.recordUsageState(.reached, for: limit.id, on: yesterday)

        // The write must actually have landed, or the assertion below is vacuous.
        #expect(service.state(for: limit, on: yesterday) == .reached)
        #expect(service.state(for: limit, on: day) == .under)
        #expect(service.state(for: limit, on: day) == .under)
    }

    @Test func clearStateDropsTodaysRecord() {
        let (service, _, store, _) = makeService()
        let limit = UsageLimit(minutesPerDay: 30)
        store.recordUsageState(.reached, for: limit.id, on: day)

        service.clearState(for: limit, screenTimeService: FakeScreenTimeService(), on: day)

        #expect(service.state(for: limit, on: day) == .under)
    }

    /// Raising a per-app limit has to lift the shields the monitor applied when
    /// it ran out, or the app stays blocked while the UI reads "Available".
    @Test func clearingASpentPerAppLimitLiftsItsShields() {
        let (service, _, store, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let limit = UsageLimit(minutesPerDay: 30)
        store.recordUsageState(.reached, for: limit.id, on: day)

        service.clearState(for: limit, screenTimeService: screenTime, on: day)

        #expect(screenTime.removeFromShieldsCalled)
    }

    @Test func clearingALimitThatWasNotSpentTouchesNoShields() {
        let (service, _, _, _) = makeService()
        let screenTime = FakeScreenTimeService()
        let limit = UsageLimit(minutesPerDay: 30)

        service.clearState(for: limit, screenTimeService: screenTime, on: day)

        #expect(screenTime.removeFromShieldsCalled == false)
    }

    // MARK: - Emergency override

    /// The override has to disarm the events too. Clearing the record alone is
    /// not enough: the next re-registration re-fires every spent threshold and
    /// silently undoes an unblock that cost one of three per 180 days.
    @Test func emergencyOverrideClearsAndDisarmsForTheRestOfTheDay() {
        let (service, center, store, _) = makeService()
        let total = UsageLimit(minutesPerDay: 30)
        service.registerAll([total], on: day)
        store.recordUsageState(.reached, for: total.id, on: day)

        service.overrideToday(on: day)

        #expect(service.state(for: total, on: day) == .under)
        #expect(service.isDayOverridden(on: day))
        #expect(center.stopCalls.last == [DeviceActivityName(SharedConstants.usageLimitsActivityName)])
    }

    @Test func anOverriddenDayRegistersNoEvents() {
        let (service, center, store, _) = makeService()
        let total = UsageLimit(minutesPerDay: 30)
        store.overrideUsageDay(on: day)
        center.startCalls.removeAll()

        service.registerAll([total], on: day)

        #expect(center.startCalls.isEmpty)
    }

    @Test func theOverrideExpiresWithTheDay() {
        let (service, _, store, _) = makeService()
        store.overrideUsageDay(on: day)

        #expect(service.isDayOverridden(on: day))
        #expect(service.isDayOverridden(on: day + .days(2)) == false)
    }

    // MARK: - Weekly policy plumbing

    @Test func theWeeklyAnchorIsReadFromTheLedgerOnLaunch() {
        let stored = Date(timeIntervalSinceReferenceDate: 500_000)
        let (service, _, _, _) = makeService(ledgerDate: stored)

        #expect(service.lastLoosenedAt == stored)
        #expect(service.lockState(now: stored + .days(1)) == .locked(until: stored + .days(7)))
    }

    @Test func committingALooseningWritesThroughToTheLedger() {
        let (service, _, _, ledger) = makeService()
        let now = Date(timeIntervalSinceReferenceDate: 700_000)

        service.commit(.cooldownElapsed, now: now)

        #expect(ledger.loadLastLoosened() == now)
        #expect(service.lastLoosenedAt == now)
    }

    @Test func committingATighteningLeavesTheLedgerUntouched() {
        let stored = Date(timeIntervalSinceReferenceDate: 500_000)
        let (service, _, _, ledger) = makeService(ledgerDate: stored)

        service.commit(.tightening, now: stored + .days(1))

        #expect(ledger.loadLastLoosened() == stored)
    }

    @Test func decideReflectsTheStoredAnchor() {
        let stored = Date(timeIntervalSinceReferenceDate: 500_000)
        let (service, _, _, _) = makeService(ledgerDate: stored)

        #expect(
            service.decide(.adjust(from: 30, to: 60, dropsCoverage: false), now: stored + .days(2))
                == .locked(until: stored + .days(7))
        )
        #expect(
            service.decide(.adjust(from: 60, to: 30, dropsCoverage: false), now: stored + .days(2))
                == .allowed(.tightening)
        )
    }
}
