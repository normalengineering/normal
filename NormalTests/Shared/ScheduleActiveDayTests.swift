import FamilyControls
import Foundation
@testable import Normal
import Testing

struct ScheduleActiveDayTests {
    // Fixed UTC Gregorian calendar so weekday values are deterministic.
    // June 2024: day 2 = Sunday(1) ... day 8 = Saturday(7).
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

    @Test func nonWrappingMondayToFridayStartOnlyOnWeekdays() {
        let s = schedule(weekdays: [2, 3, 4, 5, 6])
        for (day, weekday) in weekdayOfDay {
            let expected = (2 ... 6).contains(weekday)
            #expect(s.startApplies(on: date(day: day), calendar: cal) == expected)
        }
    }

    @Test func nonWrappingEndDoesNotFireOnUnselectedDays() {
        let s = schedule(weekdays: [2, 3, 4, 5, 6])
        // Saturday (day 8 -> weekday 7) is the reported bug: must be false.
        #expect(!s.endApplies(on: date(day: 8), calendar: cal))
        #expect(!s.endApplies(on: date(day: 2), calendar: cal)) // Sunday
        #expect(s.endApplies(on: date(day: 7), calendar: cal))  // Friday
        #expect(s.endApplies(on: date(day: 3), calendar: cal))  // Monday
    }

    @Test func wrappingScheduleDetected() {
        #expect(schedule(weekdays: [6], startHour: 23, startMinute: 0, durationMinutes: 120).wrapsPastMidnight)
        #expect(schedule(weekdays: [6], startHour: 0, startMinute: 0, durationMinutes: 1440).wrapsPastMidnight)
        #expect(!schedule(weekdays: [6], startHour: 9, startMinute: 0, durationMinutes: 60).wrapsPastMidnight)
    }

    @Test func wrappingFridayNightEndFiresSaturdayNotOtherDays() {
        // Friday only, 23:00 + 2h -> ends 01:00 Saturday.
        let s = schedule(weekdays: [6], startHour: 23, startMinute: 0, durationMinutes: 120)

        // Start only on Friday (day 7 -> weekday 6).
        #expect(s.startApplies(on: date(day: 7), calendar: cal))
        #expect(!s.startApplies(on: date(day: 8), calendar: cal))

        // End fires Saturday (day 8) and maps back to Friday start day -> true.
        #expect(s.endApplies(on: date(day: 8), calendar: cal))
        // End on Friday maps to Thursday start -> false.
        #expect(!s.endApplies(on: date(day: 7), calendar: cal))
        // End on Sunday maps to Saturday start -> false.
        #expect(!s.endApplies(on: date(day: 2), calendar: cal))
    }
}
