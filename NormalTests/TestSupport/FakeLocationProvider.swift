import CoreLocation
import Foundation
@testable import Normal

@MainActor
final class FakeLocationProvider: LocationProviding {
    enum Outcome {
        case location(CLLocation)
        case throwKeyError(LocationKeyError)
        case throwGeneric
    }

    var outcome: Outcome
    var authorizationStatus: CLAuthorizationStatus
    var cachedLocation: CLLocation?

    init(
        outcome: Outcome,
        authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse,
        cachedLocation: CLLocation? = nil
    ) {
        self.outcome = outcome
        self.authorizationStatus = authorizationStatus
        self.cachedLocation = cachedLocation
    }

    convenience init(at coordinate: CLLocationCoordinate2D) {
        self.init(outcome: .location(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)))
    }

    func currentLocation() async throws -> CLLocation {
        switch outcome {
        case let .location(location):
            return location
        case let .throwKeyError(error):
            throw error
        case .throwGeneric:
            throw NSError(domain: "test", code: 0)
        }
    }
}
