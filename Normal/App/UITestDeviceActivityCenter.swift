import DeviceActivity
import Foundation

final class UITestDeviceActivityCenter: DeviceActivityProviding {
    func startMonitoring(
        _: DeviceActivityName,
        during _: DeviceActivitySchedule,
        events _: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {}

    func stopMonitoring(_: [DeviceActivityName]) {}
}
