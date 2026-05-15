import FamilyControls
import Foundation
import SwiftData

@Model
final class BlockSchedule: Identifiable {
    @Attribute(.unique) var id: UUID

    var name: String
    var selection: FamilyActivitySelection
    var startHour: Int
    var startMinute: Int
    var durationMinutes: Int
    var weekdays: Set<Int>
    var shouldBlock: Bool
    var isTimed: Bool
    var isEnabled: Bool
    var sortIndex: Int = 0

    var formattedStartTime: String {
        var components = DateComponents()
        components.hour = startHour
        components.minute = startMinute
        guard let date = Calendar.current.date(from: components) else {
            return "\(startHour):\(String(format: "%02d", startMinute))"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    var formattedEndTime: String {
        let totalMinutes = startHour * 60 + startMinute + durationMinutes
        var components = DateComponents()
        components.hour = (totalMinutes / 60) % 24
        components.minute = totalMinutes % 60
        guard let date = Calendar.current.date(from: components) else {
            return ""
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    var formattedDuration: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    var weekdayLabels: [String] {
        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().compactMap { day in
            guard (1 ... 7).contains(day) else { return nil }
            return symbols[day - 1]
        }
    }

    init(
        name: String,
        selection: FamilyActivitySelection,
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int,
        weekdays: Set<Int>,
        shouldBlock: Bool = false,
        isTimed: Bool = true,
        isEnabled: Bool = false,
        sortIndex: Int = 0
    ) {
        id = UUID()
        self.name = name
        self.selection = selection
        self.startHour = startHour
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.weekdays = weekdays
        self.shouldBlock = shouldBlock
        self.isTimed = isTimed
        self.isEnabled = isEnabled
        self.sortIndex = sortIndex
    }

    func toDTO() -> ScheduleDTO? {
        guard let data = try? selection.toData() else { return nil }
        return ScheduleDTO(
            id: id,
            name: name,
            selectionData: data,
            startHour: startHour,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            shouldBlock: shouldBlock,
            isTimed: isTimed
        )
    }
}
