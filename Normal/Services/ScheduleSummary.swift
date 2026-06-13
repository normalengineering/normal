import Foundation

struct ScheduleSummary: Equatable {
    let total: Int
    let enabled: Int
    let activeNow: Int

    var disabled: Int { total - enabled }

    init(schedules: [BlockSchedule], now: Date = .now) {
        total = schedules.count
        enabled = schedules.filter(\.isEnabled).count
        activeNow = schedules.filter { $0.isActive(at: now) }.count
    }
}
