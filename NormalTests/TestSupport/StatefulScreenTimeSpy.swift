import FamilyControls
import Foundation
@testable import Normal

@MainActor
final class StatefulScreenTimeSpy: ScreenTimeProviding {
    var authorizationState: AuthorizationState = .authorized
    var lastUpdate: Date = .now

    private(set) var shieldActive = false
    private(set) var appDeleteDisabled = false

    private(set) var invariantViolated = false

    var isAppDeleteDisabled: Bool { appDeleteDisabled }

    private func checkInvariant() {
        if appDeleteDisabled, !shieldActive {
            invariantViolated = true
        }
    }

    func notifyUpdate() { lastUpdate = .now }
    func checkAuthorizationStatus() async {}
    func requestAuthorization() async { authorizationState = .authorized }
    func ensureAuthorized() async -> Bool { true }

    func enablePreventAppDelete() {
        appDeleteDisabled = true
        checkInvariant()
    }

    func disablePreventAppDelete() {
        appDeleteDisabled = false
        checkInvariant()
    }

    func applyShieldOnAll(selection _: FamilyActivitySelection, blockAllPreventsAppDelete: Bool) {
        shieldActive = true
        if blockAllPreventsAppDelete { appDeleteDisabled = true }
        checkInvariant()
    }

    func removeShieldOnAll(blockAllPreventsAppDelete: Bool) {
        shieldActive = false
        if blockAllPreventsAppDelete { appDeleteDisabled = false }
        checkInvariant()
    }

    func addToShields(selection _: FamilyActivitySelection) {
        shieldActive = true
        checkInvariant()
    }

    func removeFromShields(selection _: FamilyActivitySelection) {
        checkInvariant()
    }

    func activeShieldCount() -> Int { shieldActive ? 1 : 0 }
    func blockStatus(selection _: FamilyActivitySelection?) -> BlockStatus {
        shieldActive ? .all : .none
    }
}
