import FamilyControls
import Foundation
@testable import Normal
import Observation

@MainActor
@Observable
final class FakeScreenTimeService: ScreenTimeProviding {
    var authorizationState: AuthorizationState = .notAuthorized
    var lastUpdate: Date = .now

    var blockAllCalled = false
    var blockAllSelection: FamilyActivitySelection?
    var blockAllCustomDomains: [String]?
    var blockAllPreventsAppDelete: Bool?
    var unblockAllCalled = false
    var unblockAllPreventsAppDelete: Bool?
    var removeAllRestrictionsCalled = false
    var blockCalled = false
    var blockSelection: FamilyActivitySelection?
    var blockCustomDomains: [String]?
    var unblockCalled = false
    var unblockSelection: FamilyActivitySelection?
    var unblockCustomDomains: [String]?
    var reconcileCallCount = 0
    var enablePreventAppDeleteCalled = false
    var disablePreventAppDeleteCalled = false
    var notifyUpdateCallCount = 0

    var stubBlockStatus: BlockStatus = .none
    var stubActiveShieldCount: Int = 0
    var stubIsAppDeleteDisabled: Bool = false
    var stubIsAuthorizedNow: Bool = true

    var isAppDeleteDisabled: Bool {
        stubIsAppDeleteDisabled
    }

    var isAuthorizedNow: Bool {
        stubIsAuthorizedNow
    }

    func notifyUpdate() {
        notifyUpdateCallCount += 1
        lastUpdate = .now
    }

    func checkAuthorizationStatus() async {}

    func requestAuthorization() async {
        authorizationState = .authorized
    }

    func ensureAuthorized() async -> Bool {
        if authorizationState == .authorized {
            return true
        }
        await requestAuthorization()
        return authorizationState == .authorized
    }

    func enablePreventAppDelete() {
        enablePreventAppDeleteCalled = true
    }

    func disablePreventAppDelete() {
        disablePreventAppDeleteCalled = true
    }

    func blockAll(
        selection: FamilyActivitySelection,
        customDomains: [String] = [],
        blockAllPreventsAppDelete: Bool
    ) {
        blockAllCalled = true
        blockAllSelection = selection
        blockAllCustomDomains = customDomains
        self.blockAllPreventsAppDelete = blockAllPreventsAppDelete
        if blockAllPreventsAppDelete {
            enablePreventAppDelete()
        }
    }

    func unblockAll(blockAllPreventsAppDelete: Bool) {
        unblockAllCalled = true
        unblockAllPreventsAppDelete = blockAllPreventsAppDelete
        if blockAllPreventsAppDelete {
            disablePreventAppDelete()
        }
    }

    func removeAllRestrictions() {
        removeAllRestrictionsCalled = true
        disablePreventAppDelete()
    }

    func block(selection: FamilyActivitySelection, customDomains: [String] = []) {
        blockCalled = true
        blockSelection = selection
        blockCustomDomains = customDomains
    }

    func unblock(selection: FamilyActivitySelection, customDomains: [String] = []) {
        unblockCalled = true
        unblockSelection = selection
        unblockCustomDomains = customDomains
    }

    func updateMainList(
        from _: FamilyActivitySelection,
        customDomains _: [String],
        to _: FamilyActivitySelection,
        customDomains _: [String],
        addedBlockedAsOf _: Date
    ) {}

    func reconcile() {
        reconcileCallCount += 1
    }

    func activeShieldCount() -> Int {
        stubActiveShieldCount
    }

    func hasActiveCustomDomainFilter() -> Bool {
        false
    }

    func blockStatus(selection _: FamilyActivitySelection?, customDomains _: [String]? = nil) -> BlockStatus {
        stubBlockStatus
    }
}
