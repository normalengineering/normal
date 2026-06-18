import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class LocationUnlockModel {
    enum Phase: Equatable {
        case checking
        case outOfRange
        case unavailable
        case permissionDenied
        case verified
    }

    private(set) var phase: Phase = .checking
    private(set) var location: CLLocation?
    private(set) var hasValidLocation = false

    let locationKeys: [Key]
    let kind: LocationRadiusKind

    private let provider: any LocationProviding
    private let pollInterval: Duration

    private static let maxCacheAge: TimeInterval = 30

    init(keys: [Key], provider: any LocationProviding, pollInterval: Duration = .seconds(2)) {
        let locationKeys = Key.locationKeys(in: keys)
        self.locationKeys = locationKeys
        kind = locationKeys.first?.radiusKind ?? .unblock
        self.provider = provider
        self.pollInterval = pollInterval
    }

    func run() async {
        location = provider.cachedLocation
        if verifyFromCache() { return }

        while !Task.isCancelled {
            await checkOnce()
            switch phase {
            case .verified, .permissionDenied:
                return
            case .checking, .outOfRange, .unavailable:
                try? await Task.sleep(for: pollInterval)
            }
        }
    }

    func verifyFromCache() -> Bool {
        guard let cached = provider.cachedLocation,
              cached.timestamp.timeIntervalSinceNow > -Self.maxCacheAge
        else { return false }
        location = cached
        hasValidLocation = true
        guard Key.locationKeyVerifies(keys: locationKeys, location: cached) else { return false }
        phase = .verified
        return true
    }

    func checkOnce() async {
        do {
            let fix = try await provider.currentLocation()
            location = fix
            hasValidLocation = true
            phase = Key.locationKeyVerifies(keys: locationKeys, location: fix) ? .verified : .outOfRange
        } catch LocationKeyError.denied, LocationKeyError.restricted {
            phase = .permissionDenied
        } catch {
            phase = .unavailable
        }
    }
}
