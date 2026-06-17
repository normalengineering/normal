import CoreLocation
@testable import Normal
import Testing

@MainActor
struct LocationUnlockModelTests {
    private static let cupertino = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    private static let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

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

    @Test func kindIsDerivedFromKeys() {
        let model = LocationUnlockModel(keys: [locationKey(kind: .block)], provider: FakeLocationProvider(at: Self.cupertino))
        #expect(model.kind == .block)
        #expect(model.locationKeys.count == 1)
    }

    @Test func verifiesInsideUnblockZone() async {
        let model = LocationUnlockModel(keys: [locationKey(kind: .unblock)], provider: FakeLocationProvider(at: Self.cupertino))
        await model.checkOnce()
        #expect(model.phase == .verified)
    }

    @Test func outOfRangeOutsideUnblockZone() async {
        let model = LocationUnlockModel(keys: [locationKey(kind: .unblock)], provider: FakeLocationProvider(at: Self.london))
        await model.checkOnce()
        #expect(model.phase == .outOfRange)
    }

    @Test func blockKindVerifiesWhenOutside() async {
        let model = LocationUnlockModel(keys: [locationKey(kind: .block)], provider: FakeLocationProvider(at: Self.london))
        await model.checkOnce()
        #expect(model.phase == .verified)
    }

    @Test func blockKindOutOfRangeWhenInside() async {
        let model = LocationUnlockModel(keys: [locationKey(kind: .block)], provider: FakeLocationProvider(at: Self.cupertino))
        await model.checkOnce()
        #expect(model.phase == .outOfRange)
    }

    @Test func permissionDeniedOnDenied() async {
        let provider = FakeLocationProvider(outcome: .throwKeyError(.denied))
        let model = LocationUnlockModel(keys: [locationKey()], provider: provider)
        await model.checkOnce()
        #expect(model.phase == .permissionDenied)
    }

    @Test func permissionDeniedOnRestricted() async {
        let provider = FakeLocationProvider(outcome: .throwKeyError(.restricted))
        let model = LocationUnlockModel(keys: [locationKey()], provider: provider)
        await model.checkOnce()
        #expect(model.phase == .permissionDenied)
    }

    @Test func unavailableOnGenericError() async {
        let model = LocationUnlockModel(keys: [locationKey()], provider: FakeLocationProvider(outcome: .throwGeneric))
        await model.checkOnce()
        #expect(model.phase == .unavailable)
    }

    @Test func runReturnsOnceVerified() async {
        let model = LocationUnlockModel(keys: [locationKey(kind: .unblock)], provider: FakeLocationProvider(at: Self.cupertino))
        await model.run() // returns immediately on verification — no hang
        #expect(model.phase == .verified)
    }

    @Test func runReturnsOnPermissionDenied() async {
        let provider = FakeLocationProvider(outcome: .throwKeyError(.denied))
        let model = LocationUnlockModel(keys: [locationKey()], provider: provider)
        await model.run()
        #expect(model.phase == .permissionDenied)
    }
}
