@testable import Normal
import DeviceActivity
import Foundation

final class MockDeviceActivityCenter: DeviceActivityProviding {
    var startMonitoringCalled = false
    var startMonitoringName: DeviceActivityName?
    var stopMonitoringCalled = false
    var stopMonitoringNames: [DeviceActivityName]?
    var shouldThrowOnStart = false

    func startMonitoring(
        _ activityName: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        if shouldThrowOnStart {
            throw NSError(domain: "test", code: 1, userInfo: nil)
        }
        startMonitoringCalled = true
        startMonitoringName = activityName
    }

    func stopMonitoring(_ activityNames: [DeviceActivityName]) {
        stopMonitoringCalled = true
        stopMonitoringNames = activityNames
    }
}
