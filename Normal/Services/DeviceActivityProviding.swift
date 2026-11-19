import DeviceActivity
import Foundation

protocol DeviceActivityProviding {
    func startMonitoring(
        _ activityName: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws

    func stopMonitoring(_ activityNames: [DeviceActivityName])

    var monitoredActivityNames: Set<String> { get }

    func registeredSchedule(for activityName: DeviceActivityName) -> DeviceActivitySchedule?
}

extension DeviceActivityCenter: DeviceActivityProviding {
    var monitoredActivityNames: Set<String> {
        Set(activities.map(\.rawValue))
    }

    func registeredSchedule(for activityName: DeviceActivityName) -> DeviceActivitySchedule? {
        schedule(for: activityName)
    }
}

extension DeviceActivitySchedule {
    func hasSameWindow(as other: DeviceActivitySchedule) -> Bool {
        repeats == other.repeats
            && Self.time(intervalStart) == Self.time(other.intervalStart)
            && Self.time(intervalEnd) == Self.time(other.intervalEnd)
    }

    private static func time(_ components: DateComponents) -> [Int?] {
        [components.year, components.month, components.day, components.hour, components.minute, components.second ?? 0]
    }
}

extension DeviceActivityProviding {
    func syncHeartbeat(sharedStore: any SharedStoreProviding, at date: Date) {
        let name = DeviceActivityName(SharedConstants.reblockHeartbeatActivityName)
        let monitored = monitoredActivityNames
        let needed =
            sharedStore.loadSchedules().contains { $0.isEffectivelyEnabled(monitoredActivities: monitored) }
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
