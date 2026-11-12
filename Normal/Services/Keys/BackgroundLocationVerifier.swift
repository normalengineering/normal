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

    func check(keys: [Key]) async -> BackgroundLocationCheck {
        let locationKeys = Key.locationKeys(in: keys)
        guard !locationKeys.isEmpty, provider.authorizationStatus == .authorizedAlways else {
            return .unavailable
        }

        let fix: CLLocation? = if let cached = provider.cachedLocation, Self.isUsable(cached) {
            cached
        } else {
            await freshFix()
        }
        guard let fix, Self.isUsable(fix) else { return .unavailable }
        return Key.locationKeyVerifies(keys: locationKeys, location: fix) ? .verified : .outOfRange
    }

    static func isUsable(_ fix: CLLocation, now: Date = .now) -> Bool {
        fix.horizontalAccuracy >= 0
            && fix.horizontalAccuracy <= maxAccuracy
            && now.timeIntervalSince(fix.timestamp) <= LocationUnlockModel.maxCacheAge
            && fix.sourceInformation?.isSimulatedBySoftware != true
    }

    private func freshFix() async -> CLLocation? {
        let gate = FixGate()
        return await withCheckedContinuation { continuation in
            gate.continuation = continuation
            let timeout = Task {
                try? await Task.sleep(for: deadline)
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
