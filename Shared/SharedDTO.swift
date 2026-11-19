import FamilyControls
import Foundation

nonisolated struct TimedUnblockDTO: Codable, Sendable, Identifiable {
    let id: String
    let selectionData: Data
    let endDate: Date
    let activityName: String
    let isGroupUnblock: Bool
    let blockAllPreventsAppDelete: Bool?

    private let encodedCustomDomains: [String]?
    var customDomains: [String] {
        encodedCustomDomains ?? []
    }

    let startDate: Date?

    init(
        id: String,
        selectionData: Data,
        endDate: Date,
        activityName: String,
        isGroupUnblock: Bool,
        blockAllPreventsAppDelete: Bool? = nil,
        customDomains: [String]? = nil,
        startDate: Date? = nil
    ) {
        self.id = id
        self.selectionData = selectionData
        self.endDate = endDate
        self.activityName = activityName
        self.isGroupUnblock = isGroupUnblock
        self.blockAllPreventsAppDelete = blockAllPreventsAppDelete
        encodedCustomDomains = customDomains
        self.startDate = startDate
    }
}

nonisolated struct ScheduleDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let selectionData: Data
    let startHour: Int
    let startMinute: Int
    let durationMinutes: Int
    let weekdays: Set<Int>
    let shouldBlock: Bool
    let isTimed: Bool
    let isEnabled: Bool?
    let activatedAt: Date?

    private let encodedCustomDomains: [String]?
    var customDomains: [String] {
        encodedCustomDomains ?? []
    }

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
        customDomains: [String]? = nil,
        isEnabled: Bool? = nil,
        activatedAt: Date? = nil
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
        self.isEnabled = isEnabled
        self.activatedAt = activatedAt
    }
}

nonisolated extension ScheduleDTO {
    func isEffectivelyEnabled(monitoredActivities: Set<String>) -> Bool {
        isEnabled ?? monitoredActivities.contains(SharedConstants.scheduleActivityName(for: id))
    }

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        activeWindowStart(at: date, calendar: calendar) != nil
    }

    func activeWindowStart(at date: Date, calendar: Calendar = .current) -> Date? {
        ScheduleWindow.start(
            containing: date,
            startHour: startHour,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            calendar: calendar
        )
    }
}

nonisolated extension FamilyActivitySelection {
    func toData() throws -> Data {
        try PropertyListEncoder().encode(self)
    }

    static func fromData(_ data: Data) throws -> FamilyActivitySelection {
        try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func union(_ other: FamilyActivitySelection) -> FamilyActivitySelection {
        var merged = self
        merged.applicationTokens.formUnion(other.applicationTokens)
        merged.webDomainTokens.formUnion(other.webDomainTokens)
        merged.categoryTokens.formUnion(other.categoryTokens)
        return merged
    }

    func subtracting(_ other: FamilyActivitySelection) -> FamilyActivitySelection {
        var result = self
        result.applicationTokens.subtract(other.applicationTokens)
        result.webDomainTokens.subtract(other.webDomainTokens)
        result.categoryTokens.subtract(other.categoryTokens)
        return result
    }
}

nonisolated enum ScheduleWindow {
    static func start(
        containing date: Date,
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int,
        weekdays: Set<Int>,
        calendar: Calendar = .current
    ) -> Date? {
        let startOfToday = calendar.startOfDay(for: date)
        for dayOffset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                let start = calendar.date(
                    bySettingHour: startHour, minute: startMinute, second: 0, of: day
                )
            else { continue }
            let end =
                end(
                    of: day,
                    startHour: startHour,
                    startMinute: startMinute,
                    durationMinutes: durationMinutes,
                    calendar: calendar
                ) ?? start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            if weekdays.contains(calendar.component(.weekday, from: start)),
                date >= start, date < end
            {
                return start
            }
        }
        return nil
    }

    private static func end(
        of day: Date,
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int,
        calendar: Calendar
    ) -> Date? {
        let endMinute = startHour * 60 + startMinute + durationMinutes
        guard let endDay = calendar.date(byAdding: .day, value: endMinute / 1440, to: day) else { return nil }
        return calendar.date(
            bySettingHour: endMinute % 1440 / 60,
            minute: endMinute % 60,
            second: 0,
            of: endDay
        )
    }
}
