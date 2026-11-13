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
    var recentLocation: CLLocation?
    private(set) var requestCount = 0
    private var pendingContinuation: CheckedContinuation<CLLocation, Error>?
    private var requestWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(
        outcome: Outcome,
        authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse,
        cachedLocation: CLLocation? = nil,
        recentLocation: CLLocation? = nil
    ) {
        self.outcome = outcome
        self.authorizationStatus = authorizationStatus
        self.cachedLocation = cachedLocation
        self.recentLocation = recentLocation
    }

    convenience init(at coordinate: CLLocationCoordinate2D) {
        self.init(outcome: .location(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)))
    }

    func currentLocation() async throws -> CLLocation {
        requestCount += 1
        let ready = requestWaiters.filter { $0.count <= requestCount }
        requestWaiters.removeAll { $0.count <= requestCount }
        ready.forEach { $0.continuation.resume() }
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

    func waitForRequests(_ count: Int) async {
        guard requestCount < count else { return }
        await withCheckedContinuation { requestWaiters.append((count, $0)) }
    }

    func deliverPending(_ location: CLLocation) {
        pendingContinuation?.resume(returning: location)
        pendingContinuation = nil
    }
}
