import SwiftUI

struct UsageLockSchedule: TimelineSchedule {
    let dates: [Date]

    func entries(from startDate: Date, mode _: TimelineScheduleMode) -> [Date] {
        [startDate] + dates.filter { $0 > startDate }.sorted()
    }
}

enum UsageLockDeadline {
    static func phrase(until: Date, now: Date) -> Text {
        if until.timeIntervalSince(now) > UsageLimitEditPolicy.countdownLead {
            return Text("on \(until.formatted(date: .abbreviated, time: .standard))")
        }
        return Text("in \(countdown(to: until, now: now))")
    }

    static func countdown(to until: Date, now: Date) -> Text {
        Text(timerInterval: now ... max(now, until), countsDown: true)
            .monospacedDigit()
    }
}
