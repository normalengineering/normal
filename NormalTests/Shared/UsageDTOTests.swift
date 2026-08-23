import Foundation
@testable import Normal
import Testing

struct UsageDTOTests {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private var newYork: Calendar { calendar("America/New_York") }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    private let id = UUID()

    // MARK: - Day identity

    @Test func dayKeyIsStableAcrossTheSameLocalDay() {
        let morning = UsageDayKey.key(for: date("2026-03-14T00:00:01-04:00"), calendar: newYork)
        let night = UsageDayKey.key(for: date("2026-03-14T23:59:59-04:00"), calendar: newYork)

        #expect(morning == "2026-03-14")
        #expect(morning == night)
    }

    @Test func dayKeyRollsOverAtLocalMidnightNotUTC() {
        let before = UsageDayKey.key(for: date("2026-03-14T23:00:00-04:00"), calendar: newYork)
        let after = UsageDayKey.key(for: date("2026-03-15T01:00:00-04:00"), calendar: newYork)

        #expect(before == "2026-03-14")
        #expect(after == "2026-03-15")
    }

    @Test func nextResetIsTheStartOfTheFollowingLocalDay() {
        let reset = UsageDayKey.nextReset(after: date("2026-06-01T15:30:00-04:00"), calendar: newYork)

        #expect(UsageDayKey.key(for: reset, calendar: newYork) == "2026-06-02")
        #expect(reset == newYork.startOfDay(for: reset))
    }

    /// Santiago springs forward at midnight, so 00:00 does not exist that day.
    /// Matching on midnight components would miss it; start-of-day arithmetic
    /// resolves to the real first instant.
    @Test func nextResetSurvivesAZoneWhoseMidnightIsSkipped() {
        let santiago = calendar("America/Santiago")
        let beforeTransition = date("2026-09-05T20:00:00-04:00")

        let reset = UsageDayKey.nextReset(after: beforeTransition, calendar: santiago)

        #expect(reset > beforeTransition)
        #expect(UsageDayKey.key(for: reset, calendar: santiago) == "2026-09-06")
    }

    // MARK: - Day state

    @Test func unknownLimitsReadAsUnder() {
        let state = UsageDayStateDTO.fresh(on: date("2026-03-14T10:00:00-04:00"), calendar: newYork)

        #expect(state.state(for: UUID(), on: date("2026-03-14T11:00:00-04:00"), calendar: newYork) == .under)
    }

    @Test func recordedStateReadsBackWithinTheSameDay() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, calendar: newYork)
            .recording(.reached, for: id, on: noon, calendar: newYork)

        #expect(state.state(for: id, on: noon + .hours(6), calendar: newYork) == .reached)
    }

    @Test func statesOnlyEverAdvanceWithinADay() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, calendar: newYork)
            .recording(.reached, for: id, on: noon, calendar: newYork)

        #expect(state.recording(.warning, for: id, on: noon, calendar: newYork).state(for: id, on: noon, calendar: newYork) == .reached)
        #expect(state.recording(.under, for: id, on: noon, calendar: newYork).state(for: id, on: noon, calendar: newYork) == .reached)
    }

    @Test func rankOrdersStatesBySeverity() {
        #expect(UsageLimitState.under < .warning)
        #expect(UsageLimitState.warning < .reached)
        #expect([UsageLimitState.under, .reached, .warning].max() == .reached)
    }

    @Test func aRecordExpiresOnceTheNextDayHasActuallyArrived() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, calendar: newYork)
            .recording(.reached, for: id, on: noon, calendar: newYork)

        #expect(state.isStale(on: noon + .hours(6), calendar: newYork) == false)
        #expect(state.isStale(on: date("2026-03-15T09:00:00-04:00"), calendar: newYork))
        #expect(state.state(for: id, on: date("2026-03-15T09:00:00-04:00"), calendar: newYork) == .under)
    }

    /// The commitment surface must not be refundable by changing the device
    /// clock: the calendar day differs, but the real reset instant has not
    /// passed, so the spent allowance stands.
    @Test func windingTheClockBackDoesNotRefundTheDay() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, calendar: newYork)
            .recording(.reached, for: id, on: noon, calendar: newYork)

        let rolledBack = date("2026-03-13T12:00:00-04:00")

        #expect(state.isStale(on: rolledBack, calendar: newYork) == false)
        #expect(state.state(for: id, on: rolledBack, calendar: newYork) == .reached)
    }

    @Test func recordingAgainstAnExpiredDayStartsAFreshRecord() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let other = UUID()
        let nextDay = date("2026-03-15T09:00:00-04:00")

        let state = UsageDayStateDTO
            .fresh(on: noon, calendar: newYork)
            .recording(.reached, for: id, on: noon, calendar: newYork)
            .recording(.reached, for: other, on: nextDay, calendar: newYork)

        #expect(state.state(for: other, on: nextDay, calendar: newYork) == .reached)
        #expect(state.state(for: id, on: nextDay, calendar: newYork) == .under)
    }

    @Test func clearingDropsOneRecordAndLeavesTheRest() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let other = UUID()
        let state = UsageDayStateDTO
            .fresh(on: noon, calendar: newYork)
            .recording(.reached, for: id, on: noon, calendar: newYork)
            .recording(.reached, for: other, on: noon, calendar: newYork)

        let cleared = state.clearing(id, on: noon, calendar: newYork)

        #expect(cleared.state(for: id, on: noon, calendar: newYork) == .under)
        #expect(cleared.state(for: other, on: noon, calendar: newYork) == .reached)
    }

    @Test func clearingAgainstAnExpiredDayIsANoOp() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let nextDay = date("2026-03-15T09:00:00-04:00")
        let state = UsageDayStateDTO.fresh(on: noon, calendar: newYork)

        let cleared = state.clearing(id, on: nextDay, calendar: newYork)

        #expect(cleared.dayKey == "2026-03-14")
    }

    @Test func overridingClearsEveryRecordAndFlagsTheDay() {
        let noon = date("2026-03-14T12:00:00-04:00")
        let state = UsageDayStateDTO
            .fresh(on: noon, calendar: newYork)
            .recording(.reached, for: id, on: noon, calendar: newYork)
            .overriding(on: noon, calendar: newYork)

        #expect(state.isOverridden)
        #expect(state.state(for: id, on: noon, calendar: newYork) == .under)
    }

    @Test func aFreshStoreIsStaleSoTheFirstIntervalStartInitialisesIt() {
        #expect(UsageDayStateDTO.empty.isStale(on: date("2026-03-14T12:00:00-04:00"), calendar: newYork))
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
        #expect(decoded.isStale(on: date("2026-03-15T09:00:00-04:00"), calendar: newYork))
    }
}
