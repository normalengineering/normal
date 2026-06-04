import DeviceActivity
import Foundation

enum DeviceActivityScheduleFactory {
    static let minimumInterval: TimeInterval = .minutes(15)

    private static let boundaryMargin: TimeInterval = 1

    static func window(
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> DeviceActivitySchedule {
        let flooredEnd = max(end, start.addingTimeInterval(minimumInterval + boundaryMargin))
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: start),
            intervalEnd: calendar.dateComponents(fields, from: flooredEnd),
            repeats: false
        )
    }
}
