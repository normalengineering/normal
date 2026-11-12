import CoreLocation
import Foundation

enum BackgroundLocationCheck: Equatable {
    case verified
    case outOfRange
    case inconclusive
    case needsAlways
    case needsPrecise
    case noLocationKey
}

@MainActor
struct BackgroundLocationVerifier {
    static let policy = LocationFixPolicy(maxAccuracy: 100)
    static let maxTravelSpeed: CLLocationSpeed = 35

    let provider: any LocationProviding
    var deadline: Duration = .seconds(15)
    var pollInterval: Duration = .seconds(2)
    var now: () -> Date = { .now }

    static func isOutOfReach(_ margin: CLLocationDistance, within remaining: Duration) -> Bool {
        margin > maxTravelSpeed * (remaining / .seconds(1))
    }

    func check(keys: [Key]) async -> BackgroundLocationCheck {
        guard let zones = LocationZones(keys: keys) else { return .noLocationKey }
        guard provider.authorizationStatus == .authorizedAlways else { return .needsAlways }
        guard provider.accuracyAuthorization == .fullAccuracy else { return .needsPrecise }

        let clock = ContinuousClock()
        let end = clock.now.advanced(by: deadline)
        var result = BackgroundLocationCheck.inconclusive
        while !Task.isCancelled {
            let remaining = clock.now.duration(to: end)
            guard remaining > .zero else { break }
            if let fix = await freshFix(within: remaining), Self.policy.accepts(fix, now: now()) {
                switch zones.fit(fix) {
                case .satisfied:
                    return .verified
                case let .unsatisfied(margin):
                    if Self.isOutOfReach(margin, within: clock.now.duration(to: end)) {
                        return .outOfRange
                    }
                    result = .outOfRange
                case .uncertain:
                    result = .inconclusive
                }
            }
            let wait = min(pollInterval, clock.now.duration(to: end))
            guard wait > .zero else { break }
            try? await Task.sleep(for: wait)
        }
        return result
    }

    private func freshFix(within limit: Duration) async -> CLLocation? {
        let gate = FixGate()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                gate.wait(continuation)
                let timeout = Task { @MainActor in
                    try? await Task.sleep(for: limit)
                    gate.finish(with: nil)
                }
                Task { @MainActor in
                    gate.finish(with: try? await provider.currentLocation())
                    timeout.cancel()
                }
            }
        } onCancel: {
            Task { @MainActor in gate.finish(with: nil) }
        }
    }
}

@MainActor
private final class FixGate {
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var isFinished = false

    func wait(_ continuation: CheckedContinuation<CLLocation?, Never>) {
        if isFinished {
            continuation.resume(returning: nil)
        } else {
            self.continuation = continuation
        }
    }

    func finish(with fix: CLLocation?) {
        isFinished = true
        continuation?.resume(returning: fix)
        continuation = nil
    }
}
