import Foundation
@testable import Normal
import Testing

struct UsageDTOTests {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private var newYork: Calendar {
        calendar("America/New_York")
    }

    private var nyPeriod: UsagePeriod {
        UsagePeriod(calendar: newYork)
    }

    private func newYorkPeriod(resetAt hour: Int, _ minute: Int = 0) -> UsagePeriod {
        UsagePeriod(resetMinutes: hour * 60 + minute, calendar: newYork)
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    private let id = UUID()

    // MARK: - Day identity

    @Test func dayKeyIsStableAcrossTheSameLocalDay() {
        let morning = nyPeriod.key(for: date("2026-03-14T00:00:01-04:00"))
        let night = nyPeriod.key(for: date("2026-03-14T23:59:59-04:00"))

        #expect(morning == "2026-03-14")
        #expect(morning == night)
    }

    @Test func dayKeyRollsOverAtLocalMidnightNotUTC() {
        let before = nyPeriod.key(for: date("2026-03-14T23:00:00-04:00"))
        let after = nyPeriod.key(for: date("2026-03-15T01:00:00-04:00"))

        #expect(before == "2026-03-14")
        #expect(after == "2026-03-15")
    }

    @Test func nextResetIsTheStartOfTheFollowingLocalDay() {
        let reset = nyPeriod.nextReset(after: date("2026-06-01T15:30:00-04:00"))

        #expect(nyPeriod.key(for: reset) == "2026-06-02")
        #expect(reset == newYork.startOfDay(for: reset))
    }

    /// Santiago springs forward at midnight, so 00:00 does not exist that day.
    /// Matching on midnight components would miss it; start-of-day arithmetic
    /// resolves to the real first instant.
    @Test func nextResetSurvivesAZoneWhoseMidnightIsSkipped() {
        let santiago = calendar("America/Santiago")
        let beforeTransition = date("2026-09-05T20:00:00-04:00")

        let reset = UsagePeriod(calendar: santiago).nextReset(after: beforeTransition)

        #expect(reset > beforeTransition)
        #expect(UsagePeriod(calendar: santiago).key(for: reset) == "2026-09-06")
    }

    // MARK: - Day state

    @Test func unknownLimitsReadAsUnder() {
        let state = UsageDayStateDTO.fresh(on: date("2026-03-14T10:00:00-04:00"), period: nyPeriod)

        #expect(state.state(for: UUID(), on: date("2026-03-14T11:00:00-04:00"), period: nyPeriod) == .under)
    }

    @Test func recordedStateReadsBackWithinTheSameDay() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, period: nyPeriod)
            .recording(.reached, for: id, on: noon, period: nyPeriod)

        #expect(state.state(for: id, on: noon + .hours(6), period: nyPeriod) == .reached)
    }

    @Test func statesOnlyEverAdvanceWithinADay() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, period: nyPeriod)
            .recording(.reached, for: id, on: noon, period: nyPeriod)

        #expect(state.recording(.warning, for: id, on: noon, period: nyPeriod).state(for: id, on: noon, period: nyPeriod) == .reached)
        #expect(state.recording(.under, for: id, on: noon, period: nyPeriod).state(for: id, on: noon, period: nyPeriod) == .reached)
    }

    @Test func rankOrdersStatesBySeverity() {
        #expect(UsageLimitState.under < .warning)
        #expect(UsageLimitState.warning < .reached)
        #expect([UsageLimitState.under, .reached, .warning].max() == .reached)
    }

    @Test func aRecordExpiresOnceTheNextDayHasActuallyArrived() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, period: nyPeriod)
            .recording(.reached, for: id, on: noon, period: nyPeriod)

        #expect(state.isStale(on: noon + .hours(6), period: nyPeriod) == false)
        #expect(state.isStale(on: date("2026-03-15T09:00:00-04:00"), period: nyPeriod))
        #expect(state.state(for: id, on: date("2026-03-15T09:00:00-04:00"), period: nyPeriod) == .under)
    }

    /// The commitment surface must not be refundable by changing the device
    /// clock: the calendar day differs, but the real reset instant has not
    /// passed, so the spent allowance stands.
    @Test func windingTheClockBackDoesNotRefundTheDay() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, period: nyPeriod)
            .recording(.reached, for: id, on: noon, period: nyPeriod)

        let rolledBack = date("2026-03-13T12:00:00-04:00")

        #expect(state.isStale(on: rolledBack, period: nyPeriod) == false)
        #expect(state.state(for: id, on: rolledBack, period: nyPeriod) == .reached)
    }

    @Test func recordingAgainstAnExpiredDayStartsAFreshRecord() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let other = UUID()
        let nextDay = date("2026-03-15T09:00:00-04:00")

        let state = UsageDayStateDTO
            .fresh(on: noon, period: nyPeriod)
            .recording(.reached, for: id, on: noon, period: nyPeriod)
            .recording(.reached, for: other, on: nextDay, period: nyPeriod)

        #expect(state.state(for: other, on: nextDay, period: nyPeriod) == .reached)
        #expect(state.state(for: id, on: nextDay, period: nyPeriod) == .under)
    }

    @Test func clearingDropsOneRecordAndLeavesTheRest() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let other = UUID()
        let state = UsageDayStateDTO
            .fresh(on: noon, period: nyPeriod)
            .recording(.reached, for: id, on: noon, period: nyPeriod)
            .recording(.reached, for: other, on: noon, period: nyPeriod)

        let cleared = state.clearing(id, on: noon, period: nyPeriod)

        #expect(cleared.state(for: id, on: noon, period: nyPeriod) == .under)
        #expect(cleared.state(for: other, on: noon, period: nyPeriod) == .reached)
    }

    @Test func clearingAgainstAnExpiredDayIsANoOp() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let nextDay = date("2026-03-15T09:00:00-04:00")
        let state = UsageDayStateDTO.fresh(on: noon, period: nyPeriod)

        let cleared = state.clearing(id, on: nextDay, period: nyPeriod)

        #expect(cleared.dayKey == "2026-03-14")
    }

    @Test func overridingClearsEveryRecordAndFlagsTheDay() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, period: nyPeriod)
            .recording(.reached, for: id, on: noon, period: nyPeriod)
            .overriding(on: noon, period: nyPeriod)

        #expect(state.isOverridden)
        #expect(state.state(for: id, on: noon, period: nyPeriod) == .under)
    }

    @Test func aFreshStoreIsStaleSoTheFirstIntervalStartInitialisesIt() {
        #expect(UsageDayStateDTO.empty.isStale(on: date("2026-03-14T12:00:00-04:00"), period: nyPeriod))
    }

    @Test func aLaterResetKeepsTheEarlyHoursInThePreviousPeriod() {
        let period = newYorkPeriod(resetAt: 4)

        #expect(period.key(for: date("2026-03-14T03:00:00-04:00")) == "2026-03-13")
        #expect(period.key(for: date("2026-03-14T05:00:00-04:00")) == "2026-03-14")
        #expect(period.start(containing: date("2026-03-14T03:00:00-04:00")) == date("2026-03-13T04:00:00-04:00"))
    }

    @Test func nextResetIsTheNextOccurrenceOfTheResetTime() {
        let period = newYorkPeriod(resetAt: 4)

        #expect(period.nextReset(after: date("2026-06-01T03:00:00-04:00")) == date("2026-06-01T04:00:00-04:00"))
        #expect(period.nextReset(after: date("2026-06-01T04:00:00-04:00")) == date("2026-06-02T04:00:00-04:00"))
        #expect(period.nextReset(after: date("2026-06-01T05:00:00-04:00")) == date("2026-06-02T04:00:00-04:00"))
    }

    @Test func aLateEveningResetRollsTheNextDay() {
        let period = newYorkPeriod(resetAt: 23, 30)

        #expect(period.key(for: date("2026-06-01T23:45:00-04:00")) == "2026-06-01")
        #expect(period.key(for: date("2026-06-01T12:00:00-04:00")) == "2026-05-31")
        #expect(period.nextReset(after: date("2026-06-01T23:45:00-04:00")) == date("2026-06-02T23:30:00-04:00"))
    }

    @Test func aResetInsideTheSpringForwardGapResolvesAfterIt() {
        let period = newYorkPeriod(resetAt: 2, 30)
        let before = date("2026-03-08T01:00:00-05:00")

        let reset = period.nextReset(after: before)

        #expect(reset > before)
        #expect(reset <= date("2026-03-08T03:30:00-04:00"))
        #expect(period.key(for: reset) == "2026-03-08")
    }

    @Test func aRepeatedResetTimeUsesTheFirstOccurrence() {
        let period = newYorkPeriod(resetAt: 1, 30)

        let reset = period.nextReset(after: date("2026-11-01T00:00:00-04:00"))

        #expect(reset == date("2026-11-01T01:30:00-04:00"))
    }

    @Test func movingTheResetLaterKeepsASpentRecordUntilTheNewReset() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, period: nyPeriod)
            .recording(.reached, for: id, on: noon, period: nyPeriod)
        let later = newYorkPeriod(resetAt: 4)

        #expect(state.state(for: id, on: date("2026-03-15T01:00:00-04:00"), period: later) == .reached)
        #expect(state.state(for: id, on: date("2026-03-15T05:00:00-04:00"), period: later) == .under)
    }

    @Test func movingTheResetEarlierCannotRefundASpentRecord() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let later = newYorkPeriod(resetAt: 4)
        let state = UsageDayStateDTO
            .fresh(on: noon, period: later)
            .recording(.reached, for: id, on: noon, period: later)

        #expect(state.state(for: id, on: date("2026-03-15T01:00:00-04:00"), period: nyPeriod) == .reached)
        #expect(state.state(for: id, on: date("2026-03-15T09:00:00-04:00"), period: nyPeriod) == .under)
    }

    @Test func aReportClaimingMoreUseThanTimeSinceTheResetIsImplausible() {
        #expect(nyPeriod.couldHaveMetered(minutes: 60, by: date("2026-03-14T00:30:00-04:00")) == false)
        #expect(nyPeriod.couldHaveMetered(minutes: 60, by: date("2026-03-14T01:00:00-04:00")))
        #expect(nyPeriod.couldHaveMetered(minutes: 5, by: date("2026-03-14T15:00:00-04:00")))
    }

    @Test func plausibilityIsMeasuredFromTheTopOfTheResetHour() {
        let period = newYorkPeriod(resetAt: 4, 30)

        #expect(period.couldHaveMetered(minutes: 30, by: date("2026-03-14T04:45:00-04:00")))
        #expect(period.couldHaveMetered(minutes: 60, by: date("2026-03-14T04:45:00-04:00")) == false)
    }

    @Test func configSurvivesThePropertyListRoundTrip() throws {
        let config = UsageLimitConfig(resetMinutes: 270, preventsAppDelete: true)

        let decoded = try PropertyListDecoder().decode(
            UsageLimitConfig.self,
            from: PropertyListEncoder().encode(config)
        )

        #expect(decoded == config)
        #expect(decoded.period.resetMinutes == 270)
    }

    // MARK: - Wire format

    @Test func limitsSurviveThePropertyListRoundTripTheMonitorUses() throws {
        let original = UsageLimitDTO(
            id: UUID(),
            selectionData: Data([1, 2, 3]),
            minutesPerDay: 45
        )

        let encoded = try PropertyListEncoder().encode([original])
        let decoded = try PropertyListDecoder().decode([UsageLimitDTO].self, from: encoded)

        #expect(decoded.count == 1)
        #expect(decoded[0].id == original.id)
        #expect(decoded[0].minutesPerDay == 45)
        #expect(decoded[0].selectionData == original.selectionData)
    }

    /// Fields added after v1 must decode from a payload that predates them,
    /// or one missing key takes every limit down with it.
    @Test func dayStateDecodesWhenLaterFieldsAreAbsent() throws {
        let legacy: [String: Any] = ["dayKey": "2026-03-14", "states": [String: String]()]
        let data = try PropertyListSerialization.data(
            fromPropertyList: legacy, format: .binary, options: 0
        )

        let decoded = try PropertyListDecoder().decode(UsageDayStateDTO.self, from: data)

        #expect(decoded.dayKey == "2026-03-14")
        #expect(decoded.expiresAt == nil)
        #expect(decoded.isOverridden == false)
        // No stored reset instant means the day boundary alone decides.
        #expect(decoded.isStale(on: date("2026-03-15T09:00:00-04:00"), period: nyPeriod))
    }
}
