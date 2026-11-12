import CoreLocation
@testable import Normal
import Testing

struct LocationZonesTests {
    private static let center = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    private func zone(kind: LocationRadiusKind, radius: Double = 200) -> Key {
        Key(name: "Zone", latitude: Self.center.latitude, longitude: Self.center.longitude, radiusMeters: radius, radiusKind: kind)
    }

    private func fix(metersNorth: Double, accuracy: CLLocationAccuracy = 10) -> CLLocation {
        let latitude = Self.center.latitude + metersNorth / 111_320
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: Self.center.longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            timestamp: .now
        )
    }

    private func fit(_ zone: Key, _ location: CLLocation) -> LocationFit? {
        LocationZones(keys: [zone])?.fit(location)
    }

    @Test func insideAnUnblockZoneIsSatisfied() {
        #expect(fit(zone(kind: .unblock), fix(metersNorth: 50)) == .satisfied)
    }

    @Test func nearTheUnblockEdgeIsUncertain() {
        #expect(fit(zone(kind: .unblock), fix(metersNorth: 180, accuracy: 50)) == .uncertain)
    }

    @Test func outsideAnUnblockZoneIsUnsatisfied() {
        guard case let .unsatisfied(margin) = fit(zone(kind: .unblock), fix(metersNorth: 400)) else {
            Issue.record("Expected unsatisfied")
            return
        }
        #expect(abs(margin - 190) < 2)
    }

    @Test func outsideABlockZoneIsSatisfied() {
        #expect(fit(zone(kind: .block), fix(metersNorth: 400)) == .satisfied)
    }

    @Test func nearTheBlockEdgeIsUncertain() {
        #expect(fit(zone(kind: .block, radius: 50), fix(metersNorth: 60, accuracy: 65)) == .uncertain)
    }

    @Test func insideABlockZoneIsUnsatisfied() {
        guard case .unsatisfied = fit(zone(kind: .block), fix(metersNorth: 20)) else {
            Issue.record("Expected unsatisfied")
            return
        }
    }

    @Test func noLocationKeysHasNoZones() {
        #expect(LocationZones(keys: [Key(name: "QR", type: .qr, rawValue: "x")]) == nil)
    }
}
