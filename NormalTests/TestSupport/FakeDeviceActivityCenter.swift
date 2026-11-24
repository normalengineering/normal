import DeviceActivity
import ManagedSettings

@testable import Normal

final class FakeDeviceActivityCenter: DeviceActivityProviding {
    struct StartCall {
        let name: DeviceActivityName
        let schedule: DeviceActivitySchedule
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    }

    var startCalls: [StartCall] = []
    var stopCalls: [[DeviceActivityName]] = []
    var didStart: ((DeviceActivityName) -> Void)?
    var startError: Error?
    var activityLimit: Int?
    var monitoredActivityNames: Set<String> = []
    var registeredSchedules: [String: DeviceActivitySchedule] = [:]
    var reissuedApplications: Set<ApplicationToken>?

    private var registeredEvents: [DeviceActivityName: [DeviceActivityEvent.Name: DeviceActivityEvent]] = [:]

    func events(for activity: DeviceActivityName) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        let events = registeredEvents[activity] ?? [:]
        guard let reissuedApplications else { return events }
        return events.mapValues { event in
            DeviceActivityEvent(
                applications: reissuedApplications,
                categories: event.categories,
                webDomains: event.webDomains,
                threshold: event.threshold,
                includesPastActivity: event.includesPastActivity
            )
        }
    }

    func startMonitoring(
        _ activityName: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        if let startError {
            throw startError
        }
        if let activityLimit,
            !monitoredActivityNames.contains(activityName.rawValue),
            monitoredActivityNames.count >= activityLimit
        {
            throw DeviceActivityCenter.MonitoringError.excessiveActivities
        }
        startCalls.append(StartCall(name: activityName, schedule: schedule, events: events))
        monitoredActivityNames.insert(activityName.rawValue)
        registeredSchedules[activityName.rawValue] = schedule
        registeredEvents[activityName] = events
        didStart?(activityName)
    }

    func registeredSchedule(for activityName: DeviceActivityName) -> DeviceActivitySchedule? {
        registeredSchedules[activityName.rawValue]
    }

    func stopMonitoring(_ activityNames: [DeviceActivityName]) {
        stopCalls.append(activityNames)
        if activityNames.isEmpty {
            monitoredActivityNames.removeAll()
            registeredSchedules.removeAll()
            registeredEvents.removeAll()
            return
        }
        monitoredActivityNames.subtract(activityNames.map(\.rawValue))
        for name in activityNames {
            registeredEvents.removeValue(forKey: name)
            registeredSchedules.removeValue(forKey: name.rawValue)
        }
    }
}
