// BlockSchedule.swift
import FamilyControls
import Foundation
import SwiftData

enum ScheduleWeekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }
    var shortName: String { Calendar.current.shortWeekdaySymbols[rawValue - 1] }
}

@Model
final class BlockSchedule {
    @Attribute(.unique) var id: UUID
    var name: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var activeDays: [ScheduleWeekday]
    var isEnabled: Bool
    var selection: FamilyActivitySelection
    var lastUpdated: Date

    init(
        name: String,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        activeDays: [ScheduleWeekday],
        selection: FamilyActivitySelection
    ) {
        id = UUID()
        self.name = name
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.activeDays = activeDays
        self.selection = selection
        isEnabled = true
        lastUpdated = .now
    }
}
