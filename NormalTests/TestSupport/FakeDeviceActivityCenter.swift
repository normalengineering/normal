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

    func startMonitoring(
        _ activityName: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        if let startError { throw startError }
        startCalls.append(StartCall(name: activityName, schedule: schedule, events: events))
    }

    func stopMonitoring(_ activityNames: [DeviceActivityName]) {
        stopCalls.append(activityNames)
    }
}
