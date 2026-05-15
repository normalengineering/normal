import FamilyControls
import Foundation

struct TimedUnblockDTO: Codable, Sendable, Identifiable {
    let id: String
    let selectionData: Data
    let endDate: Date
    let activityName: String
    let isGroupUnblock: Bool
    let blockAllPreventsAppDelete: Bool?

    init(
        id: String,
        selectionData: Data,
        endDate: Date,
        activityName: String,
        isGroupUnblock: Bool,
        blockAllPreventsAppDelete: Bool? = nil
    ) {
        self.id = id
        self.selectionData = selectionData
        self.endDate = endDate
        self.activityName = activityName
        self.isGroupUnblock = isGroupUnblock
        self.blockAllPreventsAppDelete = blockAllPreventsAppDelete
    }
}

struct ScheduleDTO: Codable, Sendable, Identifiable {
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

extension FamilyActivitySelection {
    func toData() throws -> Data {
        try PropertyListEncoder().encode(self)
    }

    static func fromData(_ data: Data) throws -> FamilyActivitySelection {
        try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
