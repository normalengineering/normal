import Foundation
import Observation

@MainActor
@Observable
final class KeyManager {
    @discardableResult
    func performWithKeyCheck(
        using method: KeyMethod,
        action: @MainActor () -> Void
    ) async -> Bool {
        switch await method.checkKey() {
        case .success:
            action()
            return true
        case .failure, .cancelled:
            return false
        }
    }
}
