import CoreLocation
import Foundation
import Observation

enum LocationKeyError: Error, Equatable {
    case denied
    case restricted
    case unavailable
    case outOfRange

    var alertTitle: String {
        switch self {
        case .denied, .restricted: "Location Permission Needed"
        case .unavailable: "Couldn't Get Your Location"
        case .outOfRange: "Not at a Valid Location"
        }
    }

    var alertMessage: String {
        switch self {
        case .denied: "Allow location access in Settings so Normal can verify this key. Other keys still work without it."
        case .restricted: "Location access is restricted on this device. Use a different key to unlock."
        case .unavailable: "Try again with a clearer view of the sky, or use a different key."
        case .outOfRange: "Your current location doesn't satisfy any of your location keys. Move to a valid spot or use a different key."
        }
    }
}

@MainActor
protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var accuracyAuthorization: CLAccuracyAuthorization { get }
    var cachedLocation: CLLocation? { get }
    var recentLocation: CLLocation? { get }
    func currentLocation() async throws -> CLLocation
}

@MainActor
@Observable
final class LocationService: NSObject, LocationProviding {
    static let shared = LocationService()

    var authorizationStatus: CLAuthorizationStatus {
        if UITestSupport.isActive {
            return .authorizedWhenInUse
        }
        _ = authorizationRevision
        return manager.authorizationStatus
    }

    var accuracyAuthorization: CLAccuracyAuthorization {
        if UITestSupport.isActive {
            return .fullAccuracy
        }
        _ = authorizationRevision
        return manager.accuracyAuthorization
    }

    var canRequestAlways: Bool {
        switch authorizationStatus {
        case .notDetermined: true
        case .authorizedWhenInUse: !UserDefaults.standard.bool(forKey: Self.alwaysRequestedKey)
        default: false
        }
    }

    var cachedLocation: CLLocation? {
        if UITestSupport.isActive {
            return CLLocation(latitude: 37.33182, longitude: -122.03118)
        }
        return manager.location
    }

    var recentLocation: CLLocation? {
        if UITestSupport.isActive {
            return CLLocation(latitude: 37.33182, longitude: -122.03118)
        }
        guard let lastFix, lastFix.receivedAt.duration(to: .now) <= .seconds(LocationFixPolicy.maxAge) else {
            return nil
        }
        return lastFix.location
    }

    private static let alwaysRequestedKey = "locationAlwaysRequested_v1"

    private let manager = CLLocationManager()
    private var authorizationRevision = 0
    private var upgradesToAlways = false
    private var lastFix: (location: CLLocation, receivedAt: ContinuousClock.Instant)?
    private var locationContinuations: [CheckedContinuation<CLLocation, Error>] = []
    private var authContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestAlwaysAuthorization() {
        guard manager.authorizationStatus != .notDetermined else {
            upgradesToAlways = true
            manager.requestWhenInUseAuthorization()
            return
        }
        UserDefaults.standard.set(true, forKey: Self.alwaysRequestedKey)
        manager.requestAlwaysAuthorization()
    }

    func currentLocation() async throws -> CLLocation {
        if UITestSupport.isActive {
            return CLLocation(latitude: 37.33182, longitude: -122.03118)
        }
        let status = await waitForAuthorization()
        switch status {
        case .denied: throw LocationKeyError.denied
        case .restricted: throw LocationKeyError.restricted
        case .authorizedWhenInUse, .authorizedAlways: break
        default: throw LocationKeyError.unavailable
        }
        return try await withCheckedThrowingContinuation { cont in
            locationContinuations.append(cont)
            manager.requestLocation()
        }
    }

    private func waitForAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined {
            return current
        }
        manager.requestWhenInUseAuthorization()
        return await withCheckedContinuation { cont in
            authContinuations.append(cont)
        }
    }

    private func flushLocation(_ result: Result<CLLocation, Error>) {
        if case let .success(location) = result {
            lastFix = (location, .now)
        }
        let pending = locationContinuations
        locationContinuations.removeAll()
        for c in pending {
            c.resume(with: result)
        }
    }

    private func flushAuth(_ status: CLAuthorizationStatus) {
        authorizationRevision += 1
        guard status != .notDetermined else { return }
        if upgradesToAlways {
            upgradesToAlways = false
            if status == .authorizedWhenInUse {
                requestAlwaysAuthorization()
            }
        }
        let pending = authContinuations
        authContinuations.removeAll()
        for c in pending {
            c.resume(returning: status)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.flushLocation(.success(location)) }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.flushLocation(.failure(error)) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.flushAuth(status) }
    }
}
