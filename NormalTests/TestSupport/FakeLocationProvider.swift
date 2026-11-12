import CoreLocation
import Foundation
@testable import Normal

@MainActor
final class FakeLocationProvider: LocationProviding {
    enum Outcome {
        case location(CLLocation)
        case throwKeyError(LocationKeyError)
        case throwGeneric
        case pending
    }

    var outcome: Outcome
    var queuedOutcomes: [Outcome] = []
    var authorizationStatus: CLAuthorizationStatus
    var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    var cachedLocation: CLLocation?
    private(set) var requestCount = 0
    private var pendingContinuation: CheckedContinuation<CLLocation, Error>?

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
        requestCount += 1
        let next = queuedOutcomes.isEmpty ? outcome : queuedOutcomes.removeFirst()
        switch next {
        case let .location(location):
            return location
        case let .throwKeyError(error):
            throw error
        case .throwGeneric:
            throw NSError(domain: "test", code: 0)
        case .pending:
            return try await withCheckedThrowingContinuation { pendingContinuation = $0 }
        }
    }

    func finishPending() {
        pendingContinuation?.resume(throwing: LocationKeyError.unavailable)
        pendingContinuation = nil
    }
}
