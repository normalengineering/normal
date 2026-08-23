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

    /// Midnight-to-midnight repeating interval that carries the usage-limit
    /// threshold events. Restarting the interval is what resets the daily
    /// allowance, so there is no separate reset timer to keep alive.
    ///
    /// `warningTime` drives `eventWillReachThresholdWarning`, giving each limit
    /// a "nearly out" state without a second event per limit.
    static func daily(warningMinutes: Int) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true,
            warningTime: DateComponents(minute: warningMinutes)
        )
    }
}
