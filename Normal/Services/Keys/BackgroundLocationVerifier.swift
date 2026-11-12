import CoreLocation
import Foundation

enum BackgroundLocationCheck: Equatable {
    case verified
    case outOfRange
    case unavailable
}

@MainActor
struct BackgroundLocationVerifier {
    static let maxAccuracy: CLLocationAccuracy = 100

    let provider: any LocationProviding
    var deadline: Duration = .seconds(15)
    var pollInterval: Duration = .seconds(2)

    func check(keys: [Key]) async -> BackgroundLocationCheck {
        let locationKeys = Key.locationKeys(in: keys)
        guard !locationKeys.isEmpty,
              provider.authorizationStatus == .authorizedAlways,
              provider.accuracyAuthorization == .fullAccuracy
        else { return .unavailable }

        if let cached = provider.cachedLocation, Self.isUsable(cached),
           Key.locationKeyVerifies(keys: locationKeys, location: cached)
        {
            return .verified
        }

        let clock = ContinuousClock()
        let end = clock.now.advanced(by: deadline)
        var result = BackgroundLocationCheck.unavailable
        while !Task.isCancelled {
            let remaining = clock.now.duration(to: end)
            guard remaining > .zero else { break }
            if let fix = await freshFix(within: remaining), Self.isUsable(fix) {
                if Key.locationKeyVerifies(keys: locationKeys, location: fix) {
                    return .verified
                }
                result = .outOfRange
            }
            let wait = min(pollInterval, clock.now.duration(to: end))
            guard wait > .zero else { break }
            try? await Task.sleep(for: wait)
        }
        return result
    }

    static func isUsable(_ fix: CLLocation, now: Date = .now) -> Bool {
        fix.horizontalAccuracy >= 0
            && fix.horizontalAccuracy <= maxAccuracy
            && now.timeIntervalSince(fix.timestamp) <= LocationUnlockModel.maxCacheAge
            && fix.sourceInformation?.isSimulatedBySoftware != true
    }

    private func freshFix(within limit: Duration) async -> CLLocation? {
        let gate = FixGate()
        return await withCheckedContinuation { continuation in
            gate.continuation = continuation
            let timeout = Task {
                try? await Task.sleep(for: limit)
                gate.resume(with: nil)
            }
            Task {
                gate.resume(with: try? await provider.currentLocation())
                timeout.cancel()
            }
        }
    }
}

@MainActor
private final class FixGate {
    var continuation: CheckedContinuation<CLLocation?, Never>?

    func resume(with fix: CLLocation?) {
        continuation?.resume(returning: fix)
        continuation = nil
    }
}
