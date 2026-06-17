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

    let locationKeys: [Key]
    let kind: LocationRadiusKind

    private let provider: any LocationProviding
    private let pollInterval: Duration

    init(keys: [Key], provider: any LocationProviding, pollInterval: Duration = .seconds(2)) {
        let locationKeys = Key.locationKeys(in: keys)
        self.locationKeys = locationKeys
        kind = locationKeys.first?.radiusKind ?? .unblock
        self.provider = provider
        self.pollInterval = pollInterval
    }

    func run() async {
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

    func checkOnce() async {
        do {
            let location = try await provider.currentLocation()
            phase = Key.locationKeyVerifies(keys: locationKeys, location: location) ? .verified : .outOfRange
        } catch LocationKeyError.denied, LocationKeyError.restricted {
            phase = .permissionDenied
        } catch {
            phase = .unavailable
        }
    }
}
