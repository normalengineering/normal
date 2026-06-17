import FamilyControls
import Foundation
@testable import Normal
import Observation

@MainActor
@Observable
final class FakeScreenTimeService: ScreenTimeProviding {
    var authorizationState: AuthorizationState = .notAuthorized
    var lastUpdate: Date = .now

    var applyShieldOnAllCalled = false
    var applyShieldOnAllSelection: FamilyActivitySelection?
    var applyShieldOnAllCustomDomains: [String]?
    var applyShieldOnAllBlockAllPreventsAppDelete: Bool?
    var removeShieldOnAllCalled = false
    var removeShieldOnAllBlockAllPreventsAppDelete: Bool?
    var addToShieldsCalled = false
    var addToShieldsSelection: FamilyActivitySelection?
    var addToShieldsCustomDomains: [String]?
    var removeFromShieldsCalled = false
    var removeFromShieldsSelection: FamilyActivitySelection?
    var removeFromShieldsCustomDomains: [String]?
    var enablePreventAppDeleteCalled = false
    var disablePreventAppDeleteCalled = false
    var notifyUpdateCallCount = 0

    var stubBlockStatus: BlockStatus = .none
    var stubActiveShieldCount: Int = 0
    var stubIsAppDeleteDisabled: Bool = false

    var isAppDeleteDisabled: Bool { stubIsAppDeleteDisabled }

    func notifyUpdate() {
        notifyUpdateCallCount += 1
        lastUpdate = .now
    }

    func checkAuthorizationStatus() async {}

    func requestAuthorization() async {
        authorizationState = .authorized
    }

    func ensureAuthorized() async -> Bool {
        if authorizationState == .authorized { return true }
        await requestAuthorization()
        return authorizationState == .authorized
    }

    func enablePreventAppDelete() { enablePreventAppDeleteCalled = true }
    func disablePreventAppDelete() { disablePreventAppDeleteCalled = true }

    func applyShieldOnAll(
        selection: FamilyActivitySelection,
        customDomains: [String] = [],
        blockAllPreventsAppDelete: Bool
    ) {
        applyShieldOnAllCalled = true
        applyShieldOnAllSelection = selection
        applyShieldOnAllCustomDomains = customDomains
        applyShieldOnAllBlockAllPreventsAppDelete = blockAllPreventsAppDelete
        if blockAllPreventsAppDelete { enablePreventAppDelete() }
    }

    func removeShieldOnAll(blockAllPreventsAppDelete: Bool) {
        removeShieldOnAllCalled = true
        removeShieldOnAllBlockAllPreventsAppDelete = blockAllPreventsAppDelete
        if blockAllPreventsAppDelete { disablePreventAppDelete() }
    }

    func addToShields(selection: FamilyActivitySelection, customDomains: [String] = []) {
        addToShieldsCalled = true
        addToShieldsSelection = selection
        addToShieldsCustomDomains = customDomains
    }

    func removeFromShields(selection: FamilyActivitySelection, customDomains: [String] = []) {
        removeFromShieldsCalled = true
        removeFromShieldsSelection = selection
        removeFromShieldsCustomDomains = customDomains
    }

    func clearCustomDomainFilter() {}

    func activeShieldCount() -> Int { stubActiveShieldCount }
    func blockStatus(selection _: FamilyActivitySelection?, customDomains _: [String]? = nil) -> BlockStatus {
        stubBlockStatus
    }
}
