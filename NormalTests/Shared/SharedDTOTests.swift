@testable import Normal
import FamilyControls
import Foundation
import Testing

struct SharedDTOTests {
    @Test func timedUnblockDTORoundTrips() throws {
        let original = TimedUnblockDTO(
            id: "main",
            selectionData: try FamilyActivitySelection().toData(),
            endDate: Date(timeIntervalSince1970: 1_700_000_000),
            activityName: "timedUnblock_main",
            isGroupUnblock: false
        )
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(TimedUnblockDTO.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.endDate == original.endDate)
        #expect(decoded.activityName == original.activityName)
        #expect(decoded.isGroupUnblock == original.isGroupUnblock)
    }

    @Test func scheduleDTORoundTrips() throws {
        let id = UUID()
        let original = ScheduleDTO(
            id: id,
            name: "Work",
            selectionData: try FamilyActivitySelection().toData(),
            startHour: 8,
            startMinute: 30,
            durationMinutes: 60,
            weekdays: [2, 3, 4, 5, 6],
            shouldBlock: true,
            isTimed: true
        )
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(ScheduleDTO.self, from: data)
        #expect(decoded.id == id)
        #expect(decoded.startHour == 8)
        #expect(decoded.startMinute == 30)
        #expect(decoded.durationMinutes == 60)
        #expect(decoded.weekdays == [2, 3, 4, 5, 6])
        #expect(decoded.shouldBlock)
        #expect(decoded.isTimed)
    }

    @Test func familyActivitySelectionRoundTrips() throws {
        let original = FamilyActivitySelection()
        let data = try original.toData()
        let decoded = try FamilyActivitySelection.fromData(data)
        #expect(decoded.isEmpty)
    }
}
