import CoreLocation
import Foundation

struct LocationFixPolicy {
    static let maxAge: TimeInterval = 30
    static let clockTolerance: TimeInterval = 5

    var maxAccuracy: CLLocationAccuracy?

    static let inApp = LocationFixPolicy()

    func accepts(_ fix: CLLocation, now: Date = .now) -> Bool {
        let age = now.timeIntervalSince(fix.timestamp)
        guard age >= -Self.clockTolerance,
              age <= Self.maxAge,
              fix.horizontalAccuracy >= 0,
              fix.sourceInformation?.isSimulatedBySoftware != true
        else { return false }
        guard let maxAccuracy else { return true }
        return fix.horizontalAccuracy <= maxAccuracy
    }
}
