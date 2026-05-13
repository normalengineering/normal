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
    func enablePreventAppDelete()
    func disablePreventAppDelete()
    func applyShieldOnAll(selection: FamilyActivitySelection)
    func removeShieldOnAll()
    func addToShields(selection: FamilyActivitySelection)
    func removeFromShields(selection: FamilyActivitySelection)
    func activeShieldCount() -> Int
    func blockStatus(selection: FamilyActivitySelection?) -> BlockStatus
}
