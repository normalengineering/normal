import DeviceActivity
import Foundation

extension DeviceActivityProviding {
    func syncHeartbeat(sharedStore: any SharedStoreProviding, at date: Date) {
        let name = DeviceActivityName(SharedConstants.reblockHeartbeatActivityName)
        let monitored = monitoredActivityNames
        let dailyLimitsNeeded =
            monitored.contains(SharedConstants.usageLimitsActivityName)
            || DailyLimitMonitoring.eventSpecs(
                for: sharedStore.loadUsageLimits(),
                period: sharedStore.usagePeriod,
                on: date
            ).contains(where: \.isArmable)
        let needed =
            sharedStore.loadSchedules().contains { $0.isEffectivelyEnabled(monitoredActivities: monitored) }
            || dailyLimitsNeeded
            || sharedStore.loadTimedUnblocks().contains { $0.endDate > date }
        let heartbeat = DeviceActivityScheduleFactory.heartbeat()
        let current = registeredSchedule(for: name)
        if needed {
            guard current?.hasSameWindow(as: heartbeat) != true else { return }
            try? startMonitoring(name, during: heartbeat, events: [:])
        } else if current != nil || monitored.contains(name.rawValue) {
            stopMonitoring([name])
        }
    }
}
