import FamilyControls
import Foundation
@testable import Normal
import Testing

struct UsageLimitEditPolicyTests {
    private let anchor = Date(timeIntervalSinceReferenceDate: 1_000_000)

    // MARK: - Direction

    @Test func creatingALimitIsNeverLoosening() {
        #expect(UsageLimitEdit.create(minutes: 60).isLoosening == false)
    }

    @Test func loweringALimitIsNeverLoosening() {
        #expect(UsageLimitEdit.adjust(from: 60, to: 30, dropsCoverage: false).isLoosening == false)
    }

    @Test func raisingALimitIsLoosening() {
        #expect(UsageLimitEdit.adjust(from: 30, to: 60, dropsCoverage: false).isLoosening)
    }

    /// Narrowing what a limit meters is a loosening too, or the cooldown could
    /// be sidestepped by shrinking the app set instead of raising the minutes.
    @Test func narrowingWhatALimitCoversIsLoosening() {
        #expect(UsageLimitEdit.adjust(from: 60, to: 60, dropsCoverage: true).isLoosening)
        #expect(UsageLimitEdit.adjust(from: 60, to: 30, dropsCoverage: true).isLoosening)
    }

    @Test func wideningWhatALimitCoversIsNotLoosening() {
        #expect(UsageLimitEdit.adjust(from: 60, to: 60, dropsCoverage: false).isLoosening == false)
    }

    @Test func removingALimitIsLoosening() {
        #expect(UsageLimitEdit.delete(minutes: 30).isLoosening)
    }

    @Test func changingTheResetTimeIsLoosening() {
        #expect(UsageLimitEdit.changeReset.isLoosening)
    }

    @Test func changingTheResetTimeWaitsOutTheCooldown() {
        let decision = UsageLimitEditPolicy.decide(
            .changeReset,
            anchor: anchor,
            now: anchor + .days(3)
        )
        #expect(decision == .locked(until: anchor + .days(7)))
    }

    @Test func keepingALimitUnchangedIsNotLoosening() {
        #expect(UsageLimitEdit.adjust(from: 60, to: 60, dropsCoverage: false).isLoosening == false)
    }

    // MARK: - Tightening is always immediate

    @Test func tighteningIsAllowedEvenMidCooldown() {
        let decision = UsageLimitEditPolicy.decide(
            .adjust(from: 60, to: 15, dropsCoverage: false),
            anchor: anchor,
            now: anchor + .minutes(30)
        )
        #expect(decision == .allowed(.tightening))
    }

    @Test func creatingIsAllowedEvenMidCooldown() {
        let decision = UsageLimitEditPolicy.decide(
            .create(minutes: 60),
            anchor: anchor,
            now: anchor + .hours(1)
        )
        #expect(decision == .allowed(.tightening))
    }

    // MARK: - The weekly cooldown

    @Test func firstLooseningIsFree() {
        let decision = UsageLimitEditPolicy.decide(
            .adjust(from: 30, to: 60, dropsCoverage: false),
            anchor: nil,
            now: anchor
        )
        #expect(decision == .allowed(.cooldownElapsed))
    }

    @Test func looseningIsLockedUntilSevenDaysElapse() {
        let now = anchor + .days(3)
        let decision = UsageLimitEditPolicy.decide(
            .adjust(from: 30, to: 60, dropsCoverage: false),
            anchor: anchor,
            now: now
        )
        #expect(decision == .locked(until: anchor + .days(7)))
    }

    @Test func looseningIsAllowedOnceSevenDaysElapse() {
        let decision = UsageLimitEditPolicy.decide(
            .adjust(from: 30, to: 60, dropsCoverage: false),
            anchor: anchor,
            now: anchor + .days(7)
        )
        #expect(decision == .allowed(.cooldownElapsed))
    }

    @Test func deletingIsLockedByTheSameCooldown() {
        let decision = UsageLimitEditPolicy.decide(
            .delete(minutes: 30),
            anchor: anchor,
            now: anchor + .days(1)
        )
        #expect(decision == .locked(until: anchor + .days(7)))
    }

    // MARK: - The 10-minute grace window

    @Test func looseningInsideGraceIsAllowed() {
        let decision = UsageLimitEditPolicy.decide(
            .adjust(from: 30, to: 60, dropsCoverage: false),
            anchor: anchor,
            now: anchor + .minutes(9)
        )
        #expect(decision == .allowed(.grace))
    }

    @Test func graceEndsAfterTenMinutes() {
        let decision = UsageLimitEditPolicy.decide(
            .adjust(from: 30, to: 60, dropsCoverage: false),
            anchor: anchor,
            now: anchor + .minutes(10)
        )
        #expect(decision == .locked(until: anchor + .days(7)))
    }

    /// The exploit this rule exists to close: if grace re-anchored the clock,
    /// chained edits every nine minutes would postpone the cooldown forever.
    @Test func graceEditsDoNotPushTheWeeklyClockForward() {
        var current: Date? = anchor
        for step in stride(from: 1, through: 5, by: 1) {
            let now = anchor + .minutes(step)
            guard case let .allowed(allowance) = UsageLimitEditPolicy.decide(
                .adjust(from: 30, to: 30 + step, dropsCoverage: false),
                anchor: current,
                now: now
            ) else {
                Issue.record("edit inside grace should be allowed")
                return
            }
            #expect(allowance == .grace)
            current = UsageLimitEditPolicy.anchor(after: allowance, current: current, now: now)
        }
        #expect(current == anchor)
    }

    @Test(arguments: [
        UsageLimitEdit.adjust(from: 30, to: 60, dropsCoverage: false),
        .adjust(from: 60, to: 60, dropsCoverage: true),
        .delete(minutes: 30),
        .changeReset,
    ])
    func windingTheClockBackBeforeTheAnchorDoesNotReopenGrace(edit: UsageLimitEdit) {
        let decision = UsageLimitEditPolicy.decide(edit, anchor: anchor, now: anchor - .days(1))
        #expect(decision == .locked(until: anchor + .days(7)))
    }

    @Test func restoringTheClockAfterAFutureAnchorStaysLocked() {
        #expect(
            UsageLimitEditPolicy.lockState(anchor: anchor, now: anchor - 1)
                == .locked(until: anchor + .days(7))
        )
    }

    // MARK: - Anchor bookkeeping

    @Test func onlyCooldownElapsedStartsANewWeek() {
        let now = anchor + .days(8)
        #expect(
            UsageLimitEditPolicy.anchor(after: .cooldownElapsed, current: anchor, now: now) == now
        )
        #expect(
            UsageLimitEditPolicy.anchor(after: .grace, current: anchor, now: now) == anchor
        )
        #expect(
            UsageLimitEditPolicy.anchor(after: .tightening, current: anchor, now: now) == anchor
        )
    }

    @Test func tighteningNeverStartsAClockOnItsOwn() {
        #expect(
            UsageLimitEditPolicy.anchor(after: .tightening, current: nil, now: anchor) == nil
        )
    }

    // MARK: - Lock state shown before any edit is proposed

    @Test func lockStateIsUnlockedWithoutHistory() {
        #expect(UsageLimitEditPolicy.lockState(anchor: nil, now: anchor) == .unlocked)
    }

    @Test func lockStateReportsGraceThenLockThenUnlocked() {
        #expect(
            UsageLimitEditPolicy.lockState(anchor: anchor, now: anchor + .minutes(1))
                == .grace(until: anchor + .minutes(10))
        )
        #expect(
            UsageLimitEditPolicy.lockState(anchor: anchor, now: anchor + .days(2))
                == .locked(until: anchor + .days(7))
        )
        #expect(
            UsageLimitEditPolicy.lockState(anchor: anchor, now: anchor + .days(7))
                == .unlocked
        )
    }

    @Test func nothingToRefreshWithoutHistory() {
        #expect(UsageLimitEditPolicy.refreshDates(anchor: nil).isEmpty)
    }

    @Test func refreshesWhenGraceEndsWhenTheCountdownStartsAndWhenTheLockLifts() {
        #expect(
            UsageLimitEditPolicy.refreshDates(anchor: anchor) == [
                anchor + .minutes(10),
                anchor + .days(7) - .minutes(10),
                anchor + .days(7),
            ]
        )
    }
}

@MainActor
struct UsageLimitModelTests {
    @Test func aLimitFlattensToItsOwnSelectionAndAllowance() throws {
        let own = FamilyActivitySelection()
        let limit = UsageLimit(selection: own, minutesPerDay: 45)

        let dto = try #require(limit.toDTO())

        #expect(dto.id == limit.id)
        #expect(dto.minutesPerDay == 45)
        #expect(try dto.selectionData == (own.toData()))
    }

    @Test func limitsKeepTheirOrder() {
        let limits = [
            UsageLimit(minutesPerDay: 20, sortIndex: 0),
            UsageLimit(minutesPerDay: 30, sortIndex: 1),
        ]

        #expect(limits.map(\.minutesPerDay) == [20, 30])
    }

    private let created = Date(timeIntervalSinceReferenceDate: 2_000_000)

    @Test func aNewLimitCanBeAdjustedForTenMinutes() {
        let limit = UsageLimit(minutesPerDay: 30, createdAt: created)

        #expect(limit.lockState(now: created) == .grace(until: created + .minutes(10)))
        #expect(
            limit.decide(.adjust(from: 30, to: 60, dropsCoverage: false), now: created + .minutes(9))
                == .allowed(.grace)
        )
        #expect(limit.decide(.delete(minutes: 30), now: created + .minutes(9)) == .allowed(.grace))
    }

    @Test func aNewLimitLocksForSevenDaysFromCreation() {
        let limit = UsageLimit(minutesPerDay: 30, createdAt: created)

        #expect(
            limit.decide(.adjust(from: 30, to: 60, dropsCoverage: false), now: created + .minutes(10))
                == .locked(until: created + .days(7))
        )
        #expect(limit.decide(.delete(minutes: 30), now: created + .days(3)) == .locked(until: created + .days(7)))
        #expect(
            limit.decide(.adjust(from: 30, to: 20, dropsCoverage: false), now: created + .days(3))
                == .allowed(.tightening)
        )
    }

    @Test func limitsKeepSeparatePeriods() {
        let older = UsageLimit(minutesPerDay: 30, createdAt: created)
        let newer = UsageLimit(minutesPerDay: 30, createdAt: created + .days(3))
        let now = created + .days(3) + .minutes(1)

        #expect(older.lockState(now: now) == .locked(until: created + .days(7)))
        #expect(newer.lockState(now: now) == .grace(until: created + .days(3) + .minutes(10)))
    }

    @Test func aLooseningAfterThePeriodStartsANewOne() {
        let limit = UsageLimit(minutesPerDay: 30, createdAt: created)
        let later = created + .days(8)

        limit.commit(.cooldownElapsed, now: later)

        #expect(limit.lockAnchor == later)
        #expect(limit.lockState(now: later) == .grace(until: later + .minutes(10)))
    }

    @Test func changesInsideGraceDoNotExtendIt() {
        let limit = UsageLimit(minutesPerDay: 30, createdAt: created)

        limit.commit(.grace, now: created + .minutes(5))
        limit.commit(.tightening, now: created + .minutes(6))

        #expect(limit.lockAnchor == created)
    }
}
