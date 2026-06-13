import FamilyControls
import Foundation
@testable import Normal
import Testing

struct ScheduleSummaryTests {
    private let calendar = Calendar.current
    private var now: Date {
        calendar.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 12, minute: 0))!
    }

    private var today: Int { calendar.component(.weekday, from: now) }

    private func schedule(
        enabled: Bool,
        startHour: Int,
        durationMinutes: Int,
        weekdays: Set<Int>
    ) -> BlockSchedule {
        BlockSchedule(
            name: "S",
            selection: FamilyActivitySelection(),
            startHour: startHour,
            startMinute: 0,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            isEnabled: enabled
        )
    }

    @Test func emptyIsAllZero() {
        let summary = ScheduleSummary(schedules: [], now: now)
        #expect(summary == ScheduleSummary(schedules: [], now: now))
        #expect(summary.total == 0)
        #expect(summary.enabled == 0)
        #expect(summary.disabled == 0)
        #expect(summary.activeNow == 0)
    }

    @Test func countsEnabledDisabledAndActiveNow() {
        let schedules = [
            schedule(enabled: true, startHour: 11, durationMinutes: 120, weekdays: [today]),
            schedule(enabled: true, startHour: 6, durationMinutes: 60, weekdays: [today]),
            schedule(enabled: false, startHour: 11, durationMinutes: 120, weekdays: [today]),
        ]
        let summary = ScheduleSummary(schedules: schedules, now: now)
        #expect(summary.total == 3)
        #expect(summary.enabled == 2)
        #expect(summary.disabled == 1)
        #expect(summary.activeNow == 1)
    }

    @Test func enabledOnAnotherWeekdayIsNotActiveNow() {
        let otherDay = today == 1 ? 2 : 1
        let schedules = [schedule(enabled: true, startHour: 11, durationMinutes: 120, weekdays: [otherDay])]
        let summary = ScheduleSummary(schedules: schedules, now: now)
        #expect(summary.enabled == 1)
        #expect(summary.activeNow == 0)
    }

    @Test func disabledScheduleInWindowIsNotActiveNow() {
        let schedules = [schedule(enabled: false, startHour: 11, durationMinutes: 120, weekdays: [today])]
        #expect(ScheduleSummary(schedules: schedules, now: now).activeNow == 0)
    }
}
