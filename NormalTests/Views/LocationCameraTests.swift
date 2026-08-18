import CoreLocation
import MapKit
@testable import Normal
import Testing

struct LocationCameraTests {
    private static let cupertino = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    private static let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

    private func locationKey(
        at coordinate: CLLocationCoordinate2D,
        radius: Double = 200
    ) -> Key {
        Key(
            name: "Place",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: radius,
            radiusKind: .unblock
        )
    }

    @Test func focusRegionCentersOnTheCoordinate() {
        let region = LocationCamera.focusRegion(around: Self.cupertino, radiusMeters: 400)
        #expect(abs(region.center.latitude - Self.cupertino.latitude) < 1e-9)
        #expect(abs(region.center.longitude - Self.cupertino.longitude) < 1e-9)
    }

    @Test func focusRegionZoomsOutForLargerRadius() {
        let tight = LocationCamera.focusRegion(around: Self.cupertino, radiusMeters: 200)
        let wide = LocationCamera.focusRegion(around: Self.cupertino, radiusMeters: 800)
        #expect(wide.span.latitudeDelta > tight.span.latitudeDelta)
    }

    @Test func focusRegionStaysZoomedInForZeroRadius() {
        let region = LocationCamera.focusRegion(around: Self.cupertino, radiusMeters: 0)
        #expect(region.span.latitudeDelta > 0)
        #expect(region.span.latitudeDelta.isFinite)
    }

    @Test func boundingRegionCentersOnUserWhenZoneCoincides() {
        let region = LocationCamera.boundingRegion(user: Self.cupertino, keys: [locationKey(at: Self.cupertino)])
        #expect(abs(region.center.latitude - Self.cupertino.latitude) < 1e-9)
        #expect(abs(region.center.longitude - Self.cupertino.longitude) < 1e-9)
    }

    @Test func boundingRegionExpandsToFrameADistantUser() {
        let region = LocationCamera.boundingRegion(user: Self.london, keys: [locationKey(at: Self.cupertino)])
        #expect(region.center.latitude > Self.cupertino.latitude)
        #expect(region.center.latitude < Self.london.latitude)
        #expect(region.span.latitudeDelta > 15)
    }

    @Test func boundingRegionAppliesMinimumPadding() {
        let region = LocationCamera.boundingRegion(user: Self.cupertino, keys: [locationKey(at: Self.cupertino, radius: 10)])
        #expect(region.span.latitudeDelta >= 0.003)
        #expect(region.span.longitudeDelta >= 0.003)
    }

    @Test func boundingRegionWidensLongitudeAtHighLatitude() {
        let arctic = CLLocationCoordinate2D(latitude: 60, longitude: 10)
        let region = LocationCamera.boundingRegion(user: arctic, keys: [locationKey(at: arctic, radius: 1000)])
        #expect(region.span.longitudeDelta > region.span.latitudeDelta)
    }

    @Test func boundingRegionIgnoresKeysWithoutCoordinates() {
        let nfcKey = Key(name: "Tag", type: .nfc, rawValue: "abc")
        let withZone = LocationCamera.boundingRegion(user: Self.cupertino, keys: [locationKey(at: Self.cupertino)])
        let withExtraNFC = LocationCamera.boundingRegion(
            user: Self.cupertino,
            keys: [locationKey(at: Self.cupertino), nfcKey]
        )
        #expect(withZone.span.latitudeDelta == withExtraNFC.span.latitudeDelta)
        #expect(withZone.span.longitudeDelta == withExtraNFC.span.longitudeDelta)
    }
}
