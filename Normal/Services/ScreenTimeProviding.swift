import FamilyControls
import Foundation

@MainActor
protocol ScreenTimeProviding: AnyObject {
    var authorizationState: AuthorizationState { get set }
    var lastUpdate: Date { get set }
    var isAppDeleteDisabled: Bool { get }

    func notifyUpdate()
    func checkAuthorizationStatus() async
    func requestAuthorization() async
    func ensureAuthorized() async -> Bool
    func enablePreventAppDelete()
    func disablePreventAppDelete()
    func applyShieldOnAll(selection: FamilyActivitySelection, blockAllPreventsAppDelete: Bool)
    func removeShieldOnAll(blockAllPreventsAppDelete: Bool)
    func addToShields(selection: FamilyActivitySelection)
    func removeFromShields(selection: FamilyActivitySelection)
    func activeShieldCount() -> Int
    func blockStatus(selection: FamilyActivitySelection?) -> BlockStatus
}

extension ScreenTimeProviding {
    func ifAuthorized(_ action: @MainActor @escaping () -> Void) {
        Task {
            if await ensureAuthorized() {
                action()
            }
        }
    }
}
