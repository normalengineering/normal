import Foundation
@testable import Normal
import Testing

struct DTOBackCompatTests {
    // Mirrors the pre-customDomains shape of TimedUnblockDTO.
    private struct LegacyTimedUnblockDTO: Codable {
        let id: String
        let selectionData: Data
        let endDate: Date
        let activityName: String
        let isGroupUnblock: Bool
        let blockAllPreventsAppDelete: Bool?
    }

    // Mirrors the pre-customDomains shape of ScheduleDTO.
    private struct LegacyScheduleDTO: Codable {
        let id: UUID
        let name: String
        let selectionData: Data
        let startHour: Int
        let startMinute: Int
        let durationMinutes: Int
        let weekdays: Set<Int>
        let shouldBlock: Bool
        let isTimed: Bool
    }

    @Test func timedUnblockDTODecodesLegacyBlobWithoutCustomDomains() throws {
        let legacy = LegacyTimedUnblockDTO(
            id: "main",
            selectionData: Data(),
            endDate: Date(timeIntervalSince1970: 1000),
            activityName: "timedUnblock_main",
            isGroupUnblock: false,
            blockAllPreventsAppDelete: true
        )
        let blob = try PropertyListEncoder().encode(legacy)

        let decoded = try PropertyListDecoder().decode(TimedUnblockDTO.self, from: blob)
        #expect(decoded.id == "main")
        #expect(decoded.customDomains == [], "Absent key decodes to an empty list")
    }

    @Test func scheduleDTODecodesLegacyBlobWithoutCustomDomains() throws {
        let legacy = LegacyScheduleDTO(
            id: UUID(),
            name: "Work",
            selectionData: Data(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 60,
            weekdays: [2, 3, 4],
            shouldBlock: true,
            isTimed: false
        )
        let blob = try PropertyListEncoder().encode(legacy)

        let decoded = try PropertyListDecoder().decode(ScheduleDTO.self, from: blob)
        #expect(decoded.name == "Work")
        #expect(decoded.customDomains == [], "Absent key decodes to an empty list")
    }

    @Test func roundTripPreservesCustomDomains() throws {
        let dto = ScheduleDTO(
            id: UUID(),
            name: "Focus",
            selectionData: Data(),
            startHour: 8,
            startMinute: 30,
            durationMinutes: 120,
            weekdays: [2],
            shouldBlock: true,
            isTimed: true,
            customDomains: ["reddit.com", "news.com"]
        )
        let blob = try PropertyListEncoder().encode(dto)
        let decoded = try PropertyListDecoder().decode(ScheduleDTO.self, from: blob)
        #expect(decoded.customDomains == ["reddit.com", "news.com"])
    }
}
