import CoreLocation
import MapKit

enum LocationCamera {
    private static let minSpanDegrees = 0.003
    private static let spanPadding = 1.4

    static func focusRegion(around coordinate: CLLocationCoordinate2D, radiusMeters: Double) -> MKCoordinateRegion {
        let meters = max(radiusMeters, 1) * 4
        return MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters)
    }

    static func boundingRegion(user: CLLocationCoordinate2D, keys: [Key]) -> MKCoordinateRegion {
        var minLat = user.latitude, maxLat = user.latitude
        var minLon = user.longitude, maxLon = user.longitude
        for key in keys {
            guard let center = key.coordinate, let radius = key.radiusMeters else { continue }
            let latPad = radius / 111_000
            let lonPad = radius / (111_000 * max(0.01, cos(center.latitude * .pi / 180)))
            minLat = min(minLat, center.latitude - latPad)
            maxLat = max(maxLat, center.latitude + latPad)
            minLon = min(minLon, center.longitude - lonPad)
            maxLon = max(maxLon, center.longitude + lonPad)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * spanPadding + minSpanDegrees,
                longitudeDelta: (maxLon - minLon) * spanPadding + minSpanDegrees
            )
        )
    }
}
