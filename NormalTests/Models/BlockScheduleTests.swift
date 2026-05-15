import FamilyControls
import Foundation
@testable import Normal
import Testing

struct BlockScheduleTests {
    private func makeSchedule(
        startHour: Int = 9,
        startMinute: Int = 30,
        durationMinutes: Int = 60,
        weekdays: Set<Int> = [2, 3, 4, 5, 6],
        shouldBlock: Bool = true,
        isTimed: Bool = true,
        isEnabled: Bool = true
    ) -> BlockSchedule {
        BlockSchedule(
            name: "Work",
            selection: FamilyActivitySelection(),
            startHour: startHour,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            shouldBlock: shouldBlock,
            isTimed: isTimed,
            isEnabled: isEnabled
        )
    }

    @Test func formattedDurationMinutesOnly() {
        let s = makeSchedule(durationMinutes: 45)
        #expect(s.formattedDuration == "45m")
    }

    @Test func formattedDurationWholeHours() {
        let s = makeSchedule(durationMinutes: 120)
        #expect(s.formattedDuration == "2h")
    }

    @Test func formattedDurationMixed() {
        let s = makeSchedule(durationMinutes: 90)
        #expect(s.formattedDuration == "1h 30m")
    }

    @Test func formattedDurationZero() {
        let s = makeSchedule(durationMinutes: 0)
        #expect(s.formattedDuration == "0m")
    }

    @Test func weekdayLabelsAreOrdered() {
        let s = makeSchedule(weekdays: [1, 3, 5])
        let labels = s.weekdayLabels
        #expect(labels.count == 3)
    }

    @Test func weekdayLabelsSkipsInvalidValues() {
        let s = makeSchedule(weekdays: [0, 1, 9])
        let labels = s.weekdayLabels
        #expect(labels.count == 1)
    }

    @Test func startTimeFormattingHasValue() {
        let s = makeSchedule(startHour: 14, startMinute: 0)
        #expect(!s.formattedStartTime.isEmpty)
    }

    @Test func endTimeIsAfterDuration() {
        let s = makeSchedule(startHour: 8, startMinute: 0, durationMinutes: 90)
        #expect(!s.formattedEndTime.isEmpty)
    }

    @Test func endTimeWrapsPastMidnight() {
        let s = makeSchedule(startHour: 23, startMinute: 30, durationMinutes: 90)
        #expect(!s.formattedEndTime.isEmpty)
    }

    @Test func toDTOEncodesValues() {
        let s = makeSchedule(startHour: 8, startMinute: 0, durationMinutes: 60)
        let dto = s.toDTO()
        #expect(dto != nil)
        #expect(dto?.startHour == 8)
        #expect(dto?.startMinute == 0)
        #expect(dto?.durationMinutes == 60)
        #expect(dto?.shouldBlock == true)
        #expect(dto?.isTimed == true)
    }

    @Test func toDTOPreservesWeekdays() {
        let s = makeSchedule(weekdays: [2, 4, 6])
        let dto = s.toDTO()
        #expect(dto?.weekdays == [2, 4, 6])
    }

    @Test func sortIndexDefaultsToZero() {
        let s = makeSchedule()
        #expect(s.sortIndex == 0)
    }

    @Test func sortIndexHonorsExplicitValue() {
        let s = BlockSchedule(
            name: "S",
            selection: FamilyActivitySelection(),
            startHour: 0,
            startMinute: 0,
            durationMinutes: 30,
            weekdays: [2],
            sortIndex: 5
        )
        #expect(s.sortIndex == 5)
    }

    @Test func sortIndexIsMutable() {
        let s = makeSchedule()
        s.sortIndex = 99
        #expect(s.sortIndex == 99)
    }
}
