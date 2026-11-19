import DeviceActivity

@testable import Normal

final class FakeDeviceActivityCenter: DeviceActivityProviding {
    struct StartCall {
        let name: DeviceActivityName
        let schedule: DeviceActivitySchedule
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    }

    var startCalls: [StartCall] = []
    var stopCalls: [[DeviceActivityName]] = []
    var startError: Error?
    var activityLimit: Int?
    var monitoredActivityNames: Set<String> = []
    var registeredSchedules: [String: DeviceActivitySchedule] = [:]

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
    }

    func registeredSchedule(for activityName: DeviceActivityName) -> DeviceActivitySchedule? {
        registeredSchedules[activityName.rawValue]
    }

    func stopMonitoring(_ activityNames: [DeviceActivityName]) {
        stopCalls.append(activityNames)
        monitoredActivityNames.subtract(activityNames.map(\.rawValue))
        for name in activityNames {
            registeredSchedules.removeValue(forKey: name.rawValue)
        }
    }
}
