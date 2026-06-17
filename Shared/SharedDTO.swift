import FamilyControls
import Foundation

struct TimedUnblockDTO: Codable, Sendable, Identifiable {
    let id: String
    let selectionData: Data
    let endDate: Date
    let activityName: String
    let isGroupUnblock: Bool
    let blockAllPreventsAppDelete: Bool?

    private let encodedCustomDomains: [String]?
    var customDomains: [String] { encodedCustomDomains ?? [] }

    init(
        id: String,
        selectionData: Data,
        endDate: Date,
        activityName: String,
        isGroupUnblock: Bool,
        blockAllPreventsAppDelete: Bool? = nil,
        customDomains: [String]? = nil
    ) {
        self.id = id
        self.selectionData = selectionData
        self.endDate = endDate
        self.activityName = activityName
        self.isGroupUnblock = isGroupUnblock
        self.blockAllPreventsAppDelete = blockAllPreventsAppDelete
        encodedCustomDomains = customDomains
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

    private let encodedCustomDomains: [String]?
    var customDomains: [String] { encodedCustomDomains ?? [] }

    init(
        id: UUID,
        name: String,
        selectionData: Data,
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int,
        weekdays: Set<Int>,
        shouldBlock: Bool,
        isTimed: Bool,
        customDomains: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.selectionData = selectionData
        self.startHour = startHour
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.weekdays = weekdays
        self.shouldBlock = shouldBlock
        self.isTimed = isTimed
        encodedCustomDomains = customDomains
    }
}

extension ScheduleDTO {
    var wrapsPastMidnight: Bool {
        startHour * 60 + startMinute + durationMinutes >= 24 * 60
    }

    func startApplies(on date: Date, calendar: Calendar = .current) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }

    func endApplies(on date: Date, calendar: Calendar = .current) -> Bool {
        let today = calendar.component(.weekday, from: date)
        let startWeekday = wrapsPastMidnight ? (today == 1 ? 7 : today - 1) : today
        return weekdays.contains(startWeekday)
    }
}

extension FamilyActivitySelection {
    func toData() throws -> Data {
        try PropertyListEncoder().encode(self)
    }

    static func fromData(_ data: Data) throws -> FamilyActivitySelection {
        try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
