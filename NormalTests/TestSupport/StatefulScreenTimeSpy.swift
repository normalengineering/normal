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

    var isAppDeleteDisabled: Bool {
        appDeleteDisabled
    }

    var isAuthorizedNow: Bool {
        authorizationState == .authorized
    }

    private func checkInvariant() {
        if appDeleteDisabled, !shieldActive {
            invariantViolated = true
        }
    }

    func notifyUpdate() {
        lastUpdate = .now
    }

    func checkAuthorizationStatus() async {}
    func requestAuthorization() async {
        authorizationState = .authorized
    }

    func ensureAuthorized() async -> Bool {
        true
    }

    func enablePreventAppDelete() {
        appDeleteDisabled = true
        checkInvariant()
    }

    func disablePreventAppDelete() {
        appDeleteDisabled = false
        checkInvariant()
    }

    func blockAll(
        selection _: FamilyActivitySelection,
        customDomains _: [String] = [],
        blockAllPreventsAppDelete: Bool
    ) {
        shieldActive = true
        if blockAllPreventsAppDelete {
            appDeleteDisabled = true
        }
        checkInvariant()
    }

    func unblockAll(blockAllPreventsAppDelete: Bool) {
        shieldActive = false
        if blockAllPreventsAppDelete {
            appDeleteDisabled = false
        }
        checkInvariant()
    }

    func removeAllRestrictions() {
        shieldActive = false
        appDeleteDisabled = false
        checkInvariant()
    }

    func block(selection _: FamilyActivitySelection, customDomains _: [String] = []) {
        shieldActive = true
        checkInvariant()
    }

    func unblock(selection _: FamilyActivitySelection, customDomains _: [String] = []) {
        checkInvariant()
    }

    func updateMainList(
        from _: FamilyActivitySelection,
        customDomains _: [String],
        to _: FamilyActivitySelection,
        customDomains _: [String],
        addedBlockedAsOf _: Date
    ) {}

    func reconcile() {
        checkInvariant()
    }

    func activeShieldCount() -> Int {
        shieldActive ? 1 : 0
    }

    func hasActiveCustomDomainFilter() -> Bool {
        false
    }

    func blockStatus(selection _: FamilyActivitySelection?, customDomains _: [String]? = nil) -> BlockStatus {
        shieldActive ? .all : .none
    }
}
