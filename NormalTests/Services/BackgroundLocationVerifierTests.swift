import CoreLocation
import Foundation
@testable import Normal
import Testing

@MainActor
struct BackgroundLocationVerifierTests {
    private nonisolated static let cupertino = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    private static let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

    private func locationKey(kind: LocationRadiusKind = .unblock) -> Key {
        Key(
            name: "Place",
            latitude: Self.cupertino.latitude,
            longitude: Self.cupertino.longitude,
            radiusMeters: 200,
            radiusKind: kind
        )
    }

    private func fix(
        at coordinate: CLLocationCoordinate2D = cupertino,
        accuracy: CLLocationAccuracy = 10,
        age: TimeInterval = 0,
        simulated: Bool = false
    ) -> CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            course: 0,
            courseAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
            timestamp: Date().addingTimeInterval(-age),
            sourceInfo: CLLocationSourceInformation(
                softwareSimulationState: simulated,
                andExternalAccessoryState: false
            )
        )
    }

    private func provider(
        _ outcome: FakeLocationProvider.Outcome,
        status: CLAuthorizationStatus = .authorizedAlways,
        cached: CLLocation? = nil
    ) -> FakeLocationProvider {
        FakeLocationProvider(outcome: outcome, authorizationStatus: status, cachedLocation: cached)
    }

    @Test func requiresAlwaysAuthorization() async {
        let provider = provider(.location(fix()), status: .authorizedWhenInUse)
        let result = await BackgroundLocationVerifier(provider: provider).check(keys: [locationKey()])
        #expect(result == .unavailable)
        #expect(provider.requestCount == 0)
    }

    @Test func noLocationKeysIsUnavailable() async {
        let provider = provider(.location(fix()))
        let keys = [Key(name: "QR", type: .qr, rawValue: "code")]
        let result = await BackgroundLocationVerifier(provider: provider).check(keys: keys)
        #expect(result == .unavailable)
        #expect(provider.requestCount == 0)
    }

    @Test func verifiesInsideUnblockZone() async {
        let result = await BackgroundLocationVerifier(provider: provider(.location(fix())))
            .check(keys: [locationKey()])
        #expect(result == .verified)
    }

    @Test func outOfRangeOutsideUnblockZone() async {
        let result = await BackgroundLocationVerifier(provider: provider(.location(fix(at: Self.london))))
            .check(keys: [locationKey()])
        #expect(result == .outOfRange)
    }

    @Test func blockKindVerifiesWhenOutside() async {
        let result = await BackgroundLocationVerifier(provider: provider(.location(fix(at: Self.london))))
            .check(keys: [locationKey(kind: .block)])
        #expect(result == .verified)
    }

    @Test(arguments: [150.0, -1.0])
    func rejectsInaccurateFix(_ accuracy: CLLocationAccuracy) async {
        let result = await BackgroundLocationVerifier(provider: provider(.location(fix(accuracy: accuracy))))
            .check(keys: [locationKey()])
        #expect(result == .unavailable)
    }

    @Test func rejectsStaleFix() async {
        let result = await BackgroundLocationVerifier(provider: provider(.location(fix(age: 60))))
            .check(keys: [locationKey()])
        #expect(result == .unavailable)
    }

    @Test func rejectsSimulatedFix() async {
        let result = await BackgroundLocationVerifier(provider: provider(.location(fix(simulated: true))))
            .check(keys: [locationKey()])
        #expect(result == .unavailable)
    }

    @Test func freshCacheSkipsRequest() async {
        let provider = provider(.throwGeneric, cached: fix())
        let result = await BackgroundLocationVerifier(provider: provider).check(keys: [locationKey()])
        #expect(result == .verified)
        #expect(provider.requestCount == 0)
    }

    @Test func staleCacheRequestsFreshFix() async {
        let provider = provider(.location(fix()), cached: fix(at: Self.london, age: 60))
        let result = await BackgroundLocationVerifier(provider: provider).check(keys: [locationKey()])
        #expect(result == .verified)
        #expect(provider.requestCount == 1)
    }

    @Test func providerErrorIsUnavailable() async {
        let result = await BackgroundLocationVerifier(provider: provider(.throwGeneric))
            .check(keys: [locationKey()])
        #expect(result == .unavailable)
    }

    @Test func deadlineIsUnavailable() async {
        let provider = provider(.pending)
        let verifier = BackgroundLocationVerifier(provider: provider, deadline: .milliseconds(50))
        let result = await verifier.check(keys: [locationKey()])
        #expect(result == .unavailable)
        provider.finishPending()
    }
}
