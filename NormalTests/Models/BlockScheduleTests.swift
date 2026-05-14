@testable import Normal
import FamilyControls
import Foundation
import SwiftData
import Testing

struct BlockScheduleTests {
    @Test @MainActor func formattedDurationHoursOnly() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let schedule = BlockSchedule(
            name: "Test",
            selection: FamilyActivitySelection(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 120,
            weekdays: [1]
        )
        context.insert(schedule)

        #expect(schedule.formattedDuration == "2h")
    }

    @Test @MainActor func formattedDurationMinutesOnly() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let schedule = BlockSchedule(
            name: "Test",
            selection: FamilyActivitySelection(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 45,
            weekdays: [1]
        )
        context.insert(schedule)

        #expect(schedule.formattedDuration == "45m")
    }

    @Test @MainActor func formattedDurationMixed() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let schedule = BlockSchedule(
            name: "Test",
            selection: FamilyActivitySelection(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 90,
            weekdays: [1]
        )
        context.insert(schedule)

        #expect(schedule.formattedDuration == "1h 30m")
    }

    @Test @MainActor func weekdayLabelsCorrectOrder() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let schedule = BlockSchedule(
            name: "Test",
            selection: FamilyActivitySelection(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 60,
            weekdays: [1, 4, 7]
        )
        context.insert(schedule)

        let labels = schedule.weekdayLabels
        #expect(labels.count == 3)
        let symbols = Calendar.current.shortWeekdaySymbols
        #expect(labels[0] == symbols[0])
        #expect(labels[1] == symbols[3])
        #expect(labels[2] == symbols[6])
    }

    @Test @MainActor func weekdayLabelsFilterOutOfRange() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let schedule = BlockSchedule(
            name: "Test",
            selection: FamilyActivitySelection(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 60,
            weekdays: [0, 1, 8]
        )
        context.insert(schedule)

        #expect(schedule.weekdayLabels.count == 1)
    }

    @Test @MainActor func formattedStartTime() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let schedule = BlockSchedule(
            name: "Test",
            selection: FamilyActivitySelection(),
            startHour: 14,
            startMinute: 30,
            durationMinutes: 60,
            weekdays: [1]
        )
        context.insert(schedule)

        let formatted = schedule.formattedStartTime
        #expect(!formatted.isEmpty)
    }

    @Test @MainActor func formattedEndTimeWrapsAroundMidnight() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let schedule = BlockSchedule(
            name: "Test",
            selection: FamilyActivitySelection(),
            startHour: 22,
            startMinute: 0,
            durationMinutes: 180,
            weekdays: [1]
        )
        context.insert(schedule)

        let formatted = schedule.formattedEndTime
        #expect(!formatted.isEmpty)
    }

    @Test @MainActor func toDTOWithEmptySelection() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let schedule = BlockSchedule(
            name: "Test DTO",
            selection: FamilyActivitySelection(),
            startHour: 8,
            startMinute: 15,
            durationMinutes: 45,
            weekdays: [2, 4],
            shouldBlock: true,
            isTimed: false
        )
        context.insert(schedule)

        let dto = schedule.toDTO()
        #expect(dto != nil)
        #expect(dto?.name == "Test DTO")
        #expect(dto?.startHour == 8)
        #expect(dto?.startMinute == 15)
        #expect(dto?.durationMinutes == 45)
        #expect(dto?.weekdays == [2, 4])
        #expect(dto?.shouldBlock == true)
        #expect(dto?.isTimed == false)
    }
}
