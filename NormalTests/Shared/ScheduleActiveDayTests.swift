import FamilyControls
import Foundation
@testable import Normal
import Testing

struct ScheduleActiveDayTests {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(day: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: 2024, month: 6, day: day, hour: hour))!
    }

    private func schedule(
        weekdays: Set<Int>,
        startHour: Int = 9,
        startMinute: Int = 0,
        durationMinutes: Int = 60
    ) -> ScheduleDTO {
        ScheduleDTO(
            id: UUID(),
            name: "S",
            selectionData: (try? FamilyActivitySelection().toData()) ?? Data(),
            startHour: startHour,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            shouldBlock: false,
            isTimed: true
        )
    }

    private let weekdayOfDay: [Int: Int] = [
        2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 7,
    ]

    @Test func nonWrappingMondayToFridayActiveOnlyOnWeekdays() {
        let s = schedule(weekdays: [2, 3, 4, 5, 6])
        for (day, weekday) in weekdayOfDay {
            let expected = (2 ... 6).contains(weekday)
            #expect(s.isActive(at: date(day: day, hour: 9), calendar: cal) == expected)
        }
    }

    @Test func nonWrappingInactiveOutsideWindow() {
        let s = schedule(weekdays: [2, 3, 4, 5, 6])
        #expect(!s.isActive(at: date(day: 3, hour: 8), calendar: cal))
        #expect(!s.isActive(at: date(day: 3, hour: 10), calendar: cal))
    }

    @Test func wrappingStartAfterMidnightUsesDayWindowStarted() {
        // Tuesday-only 22:00–02:00. June 4 2024 is a Tuesday.
        let s = schedule(weekdays: [3], startHour: 22, durationMinutes: 240)

        #expect(!s.isActive(at: date(day: 4, hour: 1), calendar: cal))
        #expect(s.isActive(at: date(day: 4, hour: 23), calendar: cal))
        #expect(s.isActive(at: date(day: 5, hour: 1), calendar: cal))
        #expect(!s.isActive(at: date(day: 5, hour: 23), calendar: cal))
    }

    @Test func nonWrappingEndDoesNotFireOnUnselectedDays() {
        let s = schedule(weekdays: [2, 3, 4, 5, 6])
        #expect(!s.endApplies(on: date(day: 8), calendar: cal))
        #expect(!s.endApplies(on: date(day: 2), calendar: cal)) // Sunday
        #expect(s.endApplies(on: date(day: 7), calendar: cal)) // Friday
        #expect(s.endApplies(on: date(day: 3), calendar: cal)) // Monday
    }

    @Test func wrappingScheduleDetected() {
        #expect(schedule(weekdays: [6], startHour: 23, startMinute: 0, durationMinutes: 120).wrapsPastMidnight)
        #expect(schedule(weekdays: [6], startHour: 0, startMinute: 0, durationMinutes: 1440).wrapsPastMidnight)
        #expect(!schedule(weekdays: [6], startHour: 9, startMinute: 0, durationMinutes: 60).wrapsPastMidnight)
    }

    @Test func wrappingFridayNightEndFiresSaturdayNotOtherDays() {
        let s = schedule(weekdays: [6], startHour: 23, startMinute: 0, durationMinutes: 120)

        #expect(s.isActive(at: date(day: 7, hour: 23), calendar: cal))
        #expect(!s.isActive(at: date(day: 8, hour: 23), calendar: cal))
        #expect(s.endApplies(on: date(day: 8), calendar: cal))
        #expect(!s.endApplies(on: date(day: 7), calendar: cal))
        #expect(!s.endApplies(on: date(day: 2), calendar: cal))
    }
}
