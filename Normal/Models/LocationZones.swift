import CoreLocation

enum LocationFit: Equatable {
    case satisfied
    case unsatisfied(margin: CLLocationDistance)
    case uncertain
}

struct LocationZones {
    struct Circle {
        let center: CLLocation
        let radius: CLLocationDistance
    }

    let kind: LocationRadiusKind
    let circles: [Circle]

    init?(keys: [Key]) {
        let locationKeys = Key.locationKeys(in: keys)
        guard let kind = locationKeys.first?.radiusKind else { return nil }
        let circles = locationKeys.compactMap { key -> Circle? in
            guard let latitude = key.latitude, let longitude = key.longitude, let radius = key.radiusMeters else { return nil }
            return Circle(center: CLLocation(latitude: latitude, longitude: longitude), radius: radius)
        }
        guard !circles.isEmpty else { return nil }
        self.kind = kind
        self.circles = circles
    }

    func fit(_ location: CLLocation) -> LocationFit {
        guard let nearestEdge = circles.map({ location.distance(from: $0.center) - $0.radius }).min() else {
            return .uncertain
        }
        let accuracy = max(location.horizontalAccuracy, 0)
        let surelyInside = nearestEdge + accuracy <= 0
        let surelyOutside = nearestEdge - accuracy > 0
        switch kind {
        case .unblock:
            if surelyInside { return .satisfied }
            if surelyOutside { return .unsatisfied(margin: nearestEdge - accuracy) }
        case .block:
            if surelyOutside { return .satisfied }
            if surelyInside { return .unsatisfied(margin: -(nearestEdge + accuracy)) }
        }
        return .uncertain
    }
}
