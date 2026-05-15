@testable import Normal
import DeviceActivity

final class FakeDeviceActivityCenter: DeviceActivityProviding {
    struct StartCall {
        let name: DeviceActivityName
        let schedule: DeviceActivitySchedule
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
        startCalls.append(StartCall(name: activityName, schedule: schedule))
    }

    func stopMonitoring(_ activityNames: [DeviceActivityName]) {
        stopCalls.append(activityNames)
    }
}
