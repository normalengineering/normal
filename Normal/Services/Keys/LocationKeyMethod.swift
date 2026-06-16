import CoreLocation
import Foundation

struct LocationKeyMethod: KeyMethod {
    let locationProvider: any LocationProviding
    let keys: [Key]
    let onError: @MainActor (LocationKeyError) -> Void

    func checkKey() async -> KeyResult {
        do {
            let current = try await locationProvider.currentLocation()
            if Key.locationKeyVerifies(keys: keys, location: current) {
                return .success
            } else {
                await MainActor.run { onError(.outOfRange) }
                return .failure
            }
        } catch let error as LocationKeyError {
            await MainActor.run { onError(error) }
            return .failure
        } catch {
            await MainActor.run { onError(.unavailable) }
            return .failure
        }
    }
}
