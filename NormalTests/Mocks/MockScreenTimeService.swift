@testable import Normal
import FamilyControls
import Foundation
import Observation

@MainActor
@Observable
final class MockScreenTimeService: ScreenTimeProviding {
    var authorizationState: AuthorizationState = .notAuthorized
    var lastUpdate: Date = .now

    var applyShieldOnAllCalled = false
    var applyShieldOnAllSelection: FamilyActivitySelection?
    var applyShieldOnAllPreventAppDelete: Bool?
    var removeShieldOnAllCalled = false
    var removeShieldOnAllAllowAppDelete: Bool?
    var addToShieldsCalled = false
    var addToShieldsSelection: FamilyActivitySelection?
    var removeFromShieldsCalled = false
    var removeFromShieldsSelection: FamilyActivitySelection?
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

    func enablePreventAppDelete() {
        enablePreventAppDeleteCalled = true
    }

    func disablePreventAppDelete() {
        disablePreventAppDeleteCalled = true
    }

    func applyShieldOnAll(selection: FamilyActivitySelection, preventAppDelete: Bool) {
        applyShieldOnAllCalled = true
        applyShieldOnAllSelection = selection
        applyShieldOnAllPreventAppDelete = preventAppDelete
        if preventAppDelete { enablePreventAppDelete() }
    }

    func removeShieldOnAll(allowAppDelete: Bool) {
        removeShieldOnAllCalled = true
        removeShieldOnAllAllowAppDelete = allowAppDelete
        if allowAppDelete { disablePreventAppDelete() }
    }

    func addToShields(selection: FamilyActivitySelection) {
        addToShieldsCalled = true
        addToShieldsSelection = selection
    }

    func removeFromShields(selection: FamilyActivitySelection) {
        removeFromShieldsCalled = true
        removeFromShieldsSelection = selection
    }


    func activeShieldCount() -> Int { stubActiveShieldCount }

    func blockStatus(selection: FamilyActivitySelection?) -> BlockStatus { stubBlockStatus }
}
