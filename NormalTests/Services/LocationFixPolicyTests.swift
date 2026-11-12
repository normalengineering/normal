import CoreLocation
import Foundation
@testable import Normal
import Testing

struct LocationFixPolicyTests {
    private let now = Date()

    private func fix(accuracy: CLLocationAccuracy = 10, age: TimeInterval = 0, simulated: Bool = false) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            course: 0,
            courseAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
            timestamp: now.addingTimeInterval(-age),
            sourceInfo: CLLocationSourceInformation(
                softwareSimulationState: simulated,
                andExternalAccessoryState: false
            )
        )
    }

    @Test func acceptsAFreshFix() {
        #expect(LocationFixPolicy.inApp.accepts(fix(), now: now))
    }

    @Test func rejectsAnOldFix() {
        #expect(!LocationFixPolicy.inApp.accepts(fix(age: 31), now: now))
    }

    @Test func rejectsAFixFromTheFuture() {
        #expect(!LocationFixPolicy.inApp.accepts(fix(age: -60), now: now))
    }

    @Test func toleratesSmallClockDrift() {
        #expect(LocationFixPolicy.inApp.accepts(fix(age: -2), now: now))
    }

    @Test func rejectsASimulatedFix() {
        #expect(!LocationFixPolicy.inApp.accepts(fix(simulated: true), now: now))
    }

    @Test func rejectsAnInvalidFix() {
        #expect(!LocationFixPolicy.inApp.accepts(fix(accuracy: -1), now: now))
    }

    @Test func appliesAnAccuracyLimit() {
        let policy = LocationFixPolicy(maxAccuracy: 100)
        #expect(policy.accepts(fix(accuracy: 100), now: now))
        #expect(!policy.accepts(fix(accuracy: 150), now: now))
        #expect(LocationFixPolicy.inApp.accepts(fix(accuracy: 1500), now: now))
    }
}
