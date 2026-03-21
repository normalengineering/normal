import DeviceActivity
import Foundation

protocol DeviceActivityProviding {
    func startMonitoring(
        _ activityName: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws

    func stopMonitoring(_ activityNames: [DeviceActivityName])
}

extension DeviceActivityCenter: DeviceActivityProviding {}