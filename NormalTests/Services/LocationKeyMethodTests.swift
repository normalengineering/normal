import CoreLocation
@testable import Normal
import Testing

@MainActor
struct LocationKeyMethodTests {
    private static let cupertino = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    private func locationKey(
        at coordinate: CLLocationCoordinate2D = cupertino,
        radius: Double = 200,
        kind: LocationRadiusKind = .unblock
    ) -> Key {
        Key(
            name: "Place",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: radius,
            radiusKind: kind
        )
    }

    @Test func successWhenInsideUnblockZone() async {
        let provider = FakeLocationProvider(at: Self.cupertino)
        var receivedError: LocationKeyError?
        let method = LocationKeyMethod(
            locationProvider: provider,
            keys: [locationKey(kind: .unblock)],
            onError: { receivedError = $0 }
        )
        #expect(await method.checkKey() == .success)
        #expect(receivedError == nil)
    }

    @Test func failureWithOutOfRangeWhenOutsideUnblockZone() async {
        let provider = FakeLocationProvider(at: .init(latitude: 51.5074, longitude: -0.1278))
        var receivedError: LocationKeyError?
        let method = LocationKeyMethod(
            locationProvider: provider,
            keys: [locationKey(kind: .unblock)],
            onError: { receivedError = $0 }
        )
        #expect(await method.checkKey() == .failure)
        #expect(receivedError == .outOfRange)
    }

    @Test func successWhenOutsideBlockZone() async {
        let provider = FakeLocationProvider(at: .init(latitude: 51.5074, longitude: -0.1278))
        let method = LocationKeyMethod(
            locationProvider: provider,
            keys: [locationKey(kind: .block)],
            onError: { _ in }
        )
        #expect(await method.checkKey() == .success)
    }

    @Test func forwardsLocationKeyErrorFromProvider() async {
        let provider = FakeLocationProvider(outcome: .throwKeyError(.denied))
        var receivedError: LocationKeyError?
        let method = LocationKeyMethod(
            locationProvider: provider,
            keys: [locationKey()],
            onError: { receivedError = $0 }
        )
        #expect(await method.checkKey() == .failure)
        #expect(receivedError == .denied)
    }

    @Test func reportsUnavailableOnGenericError() async {
        let provider = FakeLocationProvider(outcome: .throwGeneric)
        var receivedError: LocationKeyError?
        let method = LocationKeyMethod(
            locationProvider: provider,
            keys: [locationKey()],
            onError: { receivedError = $0 }
        )
        #expect(await method.checkKey() == .failure)
        #expect(receivedError == .unavailable)
    }
}
