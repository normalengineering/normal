import CoreLocation
import Foundation
@testable import Normal
import Testing

@MainActor
struct BackgroundLocationVerifierTests {
    private nonisolated static let cupertino = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    private static let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    private let now = Date()

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
        metersNorth: Double = 0,
        accuracy: CLLocationAccuracy = 10,
        age: TimeInterval = 0,
        simulated: Bool = false
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: coordinate.latitude + metersNorth / 111_320,
                longitude: coordinate.longitude
            ),
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

    private func provider(
        _ outcome: FakeLocationProvider.Outcome,
        status: CLAuthorizationStatus = .authorizedAlways
    ) -> FakeLocationProvider {
        FakeLocationProvider(outcome: outcome, authorizationStatus: status)
    }

    private func check(
        _ provider: FakeLocationProvider,
        keys: [Key]? = nil,
        deadline: Duration = .milliseconds(150)
    ) async -> BackgroundLocationCheck {
        let now = now
        let verifier = BackgroundLocationVerifier(provider: provider, deadline: deadline, pollInterval: .milliseconds(1), now: { now })
        return await verifier.check(keys: keys ?? [locationKey()])
    }

    @Test func noLocationKeys() async {
        let provider = provider(.location(fix()))
        #expect(await check(provider, keys: [Key(name: "QR", type: .qr, rawValue: "code")]) == .noLocationKey)
        #expect(provider.requestCount == 0)
    }

    @Test func requiresAlwaysAuthorization() async {
        let provider = provider(.location(fix()), status: .authorizedWhenInUse)
        #expect(await check(provider) == .needsAlways)
        #expect(provider.requestCount == 0)
    }

    @Test func requiresPreciseLocation() async {
        let provider = provider(.location(fix()))
        provider.accuracyAuthorization = .reducedAccuracy
        #expect(await check(provider) == .needsPrecise)
        #expect(provider.requestCount == 0)
    }

    @Test func verifiesInsideUnblockZone() async {
        #expect(await check(provider(.location(fix())), deadline: .seconds(300)) == .verified)
    }

    @Test func blockKindVerifiesWhenOutside() async {
        #expect(await check(provider(.location(fix(at: Self.london))), keys: [locationKey(kind: .block)], deadline: .seconds(300)) == .verified)
    }

    @Test func farOutsideFailsWithoutWaiting() async {
        let provider = provider(.location(fix(at: Self.london)))
        #expect(await check(provider, deadline: .seconds(300)) == .outOfRange)
        #expect(provider.requestCount == 1)
    }

    @Test func justOutsideWithNoTimeToWalkInIsOutOfRange() async {
        let provider = provider(.pending)
        provider.queuedOutcomes = [.location(fix(metersNorth: 300))]
        #expect(await check(provider, deadline: .seconds(1)) == .outOfRange)
        provider.finishPending()
    }

    @Test func justOutsideKeepsChecking() async {
        let provider = provider(.location(fix()))
        provider.queuedOutcomes = [.location(fix(metersNorth: 300)), .location(fix(metersNorth: 250))]
        #expect(await check(provider, deadline: .seconds(300)) == .verified)
        #expect(provider.requestCount == 3)
    }

    @Test(.timeLimit(.minutes(5))) func latestReadingDecidesTheResult() async {
        let provider = provider(.pending)
        provider.queuedOutcomes = [.location(fix(metersNorth: 220)), .location(fix(metersNorth: 190, accuracy: 50))]
        let now = now
        let verifier = BackgroundLocationVerifier(provider: provider, deadline: .seconds(300), pollInterval: .milliseconds(1), now: { now })
        let task = Task { await verifier.check(keys: [locationKey()]) }
        await provider.waitForRequests(3)
        task.cancel()
        #expect(await task.value == .inconclusive)
        provider.finishPending()
    }

    @Test func reachShrinksAsTheDeadlineNears() {
        #expect(BackgroundLocationVerifier.isOutOfReach(600, within: .seconds(15)))
        #expect(!BackgroundLocationVerifier.isOutOfReach(170, within: .seconds(15)))
        #expect(BackgroundLocationVerifier.isOutOfReach(170, within: .seconds(4)))
    }

    @Test func verifiesOnceTheDeviceWalksIn() async {
        let provider = provider(.location(fix()))
        provider.queuedOutcomes = [.location(fix(metersNorth: 300))]
        #expect(await check(provider, deadline: .seconds(300)) == .verified)
        #expect(provider.requestCount == 2)
    }

    @Test func fixAtTheEdgeIsInconclusive() async {
        #expect(await check(provider(.location(fix(metersNorth: 190, accuracy: 50)))) == .inconclusive)
    }

    @Test(arguments: [150.0, -1.0])
    func rejectsInaccurateFix(_ accuracy: CLLocationAccuracy) async {
        #expect(await check(provider(.location(fix(accuracy: accuracy)))) == .inconclusive)
    }

    @Test func rejectsStaleFix() async {
        #expect(await check(provider(.location(fix(age: 60)))) == .inconclusive)
    }

    @Test func rejectsFutureDatedFix() async {
        #expect(await check(provider(.location(fix(age: -120)))) == .inconclusive)
    }

    @Test func rejectsSimulatedFix() async {
        #expect(await check(provider(.location(fix(simulated: true)))) == .inconclusive)
    }

    @Test func ignoresTheCachedLocation() async {
        let provider = provider(.throwGeneric)
        provider.recentLocation = fix()
        provider.cachedLocation = fix()
        #expect(await check(provider) == .inconclusive)
    }

    @Test func noFixBeforeTheDeadlineIsInconclusive() async {
        let provider = provider(.pending)
        #expect(await check(provider) == .inconclusive)
        provider.finishPending()
    }

    @Test func cancellingStopsTheCheck() async {
        let provider = provider(.pending)
        let verifier = BackgroundLocationVerifier(provider: provider, deadline: .seconds(300))
        let task = Task { await verifier.check(keys: [locationKey()]) }
        while provider.requestCount == 0 {
            await Task.yield()
        }
        task.cancel()
        #expect(await task.value == .inconclusive)
        provider.finishPending()
    }
}
