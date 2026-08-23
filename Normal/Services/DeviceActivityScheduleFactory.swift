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

    static func daily(resetMinutes: Int, warningMinutes: Int) -> DeviceActivitySchedule {
        let startSeconds = resetMinutes * 60
        let endSeconds = (startSeconds - 1 + 86400) % 86400
        return DeviceActivitySchedule(
            intervalStart: DateComponents(hour: resetMinutes / 60, minute: resetMinutes % 60, second: 0),
            intervalEnd: DateComponents(
                hour: endSeconds / 3600,
                minute: endSeconds % 3600 / 60,
                second: endSeconds % 60
            ),
            repeats: true,
            warningTime: DateComponents(minute: warningMinutes)
        )
    }
}
