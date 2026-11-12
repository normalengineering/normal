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

    private func check(
        _ provider: FakeLocationProvider,
        keys: [Key]? = nil,
        deadline: Duration = .milliseconds(150)
    ) async -> BackgroundLocationCheck {
        let verifier = BackgroundLocationVerifier(
            provider: provider,
            deadline: deadline,
            pollInterval: .milliseconds(1)
        )
        return await verifier.check(keys: keys ?? [locationKey()])
    }

    @Test func requiresAlwaysAuthorization() async {
        let provider = provider(.location(fix()), status: .authorizedWhenInUse)
        #expect(await check(provider) == .unavailable)
        #expect(provider.requestCount == 0)
    }

    @Test func requiresPreciseLocation() async {
        let provider = provider(.location(fix()))
        provider.accuracyAuthorization = .reducedAccuracy
        #expect(await check(provider) == .unavailable)
        #expect(provider.requestCount == 0)
    }

    @Test func noLocationKeysIsUnavailable() async {
        let provider = provider(.location(fix()))
        let keys = [Key(name: "QR", type: .qr, rawValue: "code")]
        #expect(await check(provider, keys: keys) == .unavailable)
        #expect(provider.requestCount == 0)
    }

    @Test func verifiesInsideUnblockZone() async {
        #expect(await check(provider(.location(fix()))) == .verified)
    }

    @Test func outOfRangeAtTheDeadlineIsOutOfRange() async {
        #expect(await check(provider(.location(fix(at: Self.london)))) == .outOfRange)
    }

    @Test func verifiesOnceTheDeviceMovesIntoTheZone() async {
        let provider = provider(.location(fix()))
        provider.queuedOutcomes = [.location(fix(at: Self.london))]
        #expect(await check(provider, deadline: .seconds(30)) == .verified)
        #expect(provider.requestCount == 2)
    }

    @Test func blockKindVerifiesWhenOutside() async {
        let result = await check(provider(.location(fix(at: Self.london))), keys: [locationKey(kind: .block)])
        #expect(result == .verified)
    }

    @Test(arguments: [150.0, -1.0])
    func rejectsInaccurateFix(_ accuracy: CLLocationAccuracy) async {
        #expect(await check(provider(.location(fix(accuracy: accuracy)))) == .unavailable)
    }

    @Test func rejectsStaleFix() async {
        #expect(await check(provider(.location(fix(age: 60)))) == .unavailable)
    }

    @Test func rejectsSimulatedFix() async {
        #expect(await check(provider(.location(fix(simulated: true)))) == .unavailable)
    }

    @Test func freshCacheInsideTheZoneSkipsRequest() async {
        let provider = provider(.throwGeneric, cached: fix())
        #expect(await check(provider) == .verified)
        #expect(provider.requestCount == 0)
    }

    @Test func freshCacheOutsideTheZoneStillRequestsAFix() async {
        let provider = provider(.location(fix()), cached: fix(at: Self.london))
        #expect(await check(provider) == .verified)
        #expect(provider.requestCount == 1)
    }

    @Test func staleCacheRequestsAFix() async {
        let provider = provider(.location(fix()), cached: fix(age: 60))
        #expect(await check(provider) == .verified)
        #expect(provider.requestCount == 1)
    }

    @Test func providerErrorIsUnavailable() async {
        #expect(await check(provider(.throwGeneric)) == .unavailable)
    }

    @Test func noFixBeforeTheDeadlineIsUnavailable() async {
        let provider = provider(.pending)
        #expect(await check(provider) == .unavailable)
        provider.finishPending()
    }
}
