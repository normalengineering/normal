import DeviceActivity
import Foundation

final class UITestDeviceActivityCenter: DeviceActivityProviding {
    private var schedules: [String: DeviceActivitySchedule] = [:]
    var onUsageLimitsStarted: (([DeviceActivityEvent.Name: DeviceActivityEvent]) -> Void)?

    var monitoredActivityNames: Set<String> {
        Set(schedules.keys)
    }

    private var registeredEvents: [DeviceActivityName: [DeviceActivityEvent.Name: DeviceActivityEvent]] = [:]

    func events(for activity: DeviceActivityName) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        registeredEvents[activity] ?? [:]
    }

    func startMonitoring(
        _ activityName: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        if activityName.rawValue.hasPrefix("timedUnblock_") {
            if UITestSupport.timedUnblockFails {
                throw DeviceActivityCenter.MonitoringError.unauthorized
            }
            if UITestSupport.timerLimitReached {
                throw DeviceActivityCenter.MonitoringError.excessiveActivities
            }
        }
        schedules[activityName.rawValue] = schedule
        registeredEvents[activityName] = events
        if activityName.rawValue == SharedConstants.usageLimitsActivityName {
            onUsageLimitsStarted?(events)
        }
    }

    func stopMonitoring(_ activityNames: [DeviceActivityName]) {
        if activityNames.isEmpty {
            schedules.removeAll()
            registeredEvents.removeAll()
            return
        }
        for name in activityNames {
            registeredEvents.removeValue(forKey: name)
            schedules.removeValue(forKey: name.rawValue)
        }
    }

    func registeredSchedule(for activityName: DeviceActivityName) -> DeviceActivitySchedule? {
        schedules[activityName.rawValue]
    }
}
