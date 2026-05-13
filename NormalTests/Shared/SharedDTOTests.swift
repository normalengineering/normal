@testable import Normal
import FamilyControls
import Foundation
import Testing

struct SharedDTOTests {
    @Test func timedUnblockDTOCodableRoundtrip() throws {
        let selection = FamilyActivitySelection()
        let dto = try TimedUnblockDTO(
            id: "test",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(3600),
            activityName: "activity_test",
            isGroupUnblock: false
        )

        let encoded = try PropertyListEncoder().encode(dto)
        let decoded = try PropertyListDecoder().decode(TimedUnblockDTO.self, from: encoded)

        #expect(decoded.id == dto.id)
        #expect(decoded.activityName == dto.activityName)
        #expect(decoded.isGroupUnblock == dto.isGroupUnblock)
    }

    @Test func scheduleDTOCodableRoundtrip() throws {
        let selection = FamilyActivitySelection()
        let dto = ScheduleDTO(
            id: UUID(),
            name: "Test Schedule",
            selectionData: try selection.toData(),
            startHour: 9,
            startMinute: 30,
            durationMinutes: 120,
            weekdays: [1, 3, 5],
            shouldBlock: true,
            isTimed: true
        )

        let encoded = try PropertyListEncoder().encode(dto)
        let decoded = try PropertyListDecoder().decode(ScheduleDTO.self, from: encoded)

        #expect(decoded.id == dto.id)
        #expect(decoded.name == dto.name)
        #expect(decoded.startHour == dto.startHour)
        #expect(decoded.startMinute == dto.startMinute)
        #expect(decoded.durationMinutes == dto.durationMinutes)
        #expect(decoded.weekdays == dto.weekdays)
        #expect(decoded.shouldBlock == dto.shouldBlock)
        #expect(decoded.isTimed == dto.isTimed)
    }

    @Test func familyActivitySelectionToDataAndBack() throws {
        let original = FamilyActivitySelection()
        let data = try original.toData()
        let restored = try FamilyActivitySelection.fromData(data)

        #expect(restored.applicationTokens.isEmpty)
        #expect(restored.webDomainTokens.isEmpty)
        #expect(restored.categoryTokens.isEmpty)
    }
}
