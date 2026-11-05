import FamilyControls
import Foundation

@MainActor
protocol ScreenTimeProviding: AnyObject {
    var authorizationState: AuthorizationState { get set }
    var lastUpdate: Date { get set }
    var isAppDeleteDisabled: Bool { get }
    var isAuthorizedNow: Bool { get }

    func notifyUpdate()
    func checkAuthorizationStatus() async
    func requestAuthorization() async
    func ensureAuthorized() async -> Bool
    func enablePreventAppDelete()
    func disablePreventAppDelete()
    func blockAll(
        selection: FamilyActivitySelection,
        customDomains: [String],
        blockAllPreventsAppDelete: Bool
    )
    func unblockAll(blockAllPreventsAppDelete: Bool)
    func block(selection: FamilyActivitySelection, customDomains: [String])
    func unblock(selection: FamilyActivitySelection, customDomains: [String])
    func updateMainList(
        from old: FamilyActivitySelection,
        customDomains oldDomains: [String],
        to new: FamilyActivitySelection,
        customDomains newDomains: [String],
        addedBlockedAsOf addedDate: Date
    )
    func removeAllRestrictions()
    func reconcile()
    func activeShieldCount() -> Int
    func blockStatus(selection: FamilyActivitySelection?, customDomains: [String]?) -> BlockStatus
    func hasActiveCustomDomainFilter() -> Bool
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
