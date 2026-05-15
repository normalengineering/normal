@testable import Normal
import FamilyControls
import Foundation
import Observation

@MainActor
@Observable
final class FakeScreenTimeService: ScreenTimeProviding {
    var authorizationState: AuthorizationState = .notAuthorized
    var lastUpdate: Date = .now

    var applyShieldOnAllCalled = false
    var applyShieldOnAllSelection: FamilyActivitySelection?
    var applyShieldOnAllBlockAllPreventsAppDelete: Bool?
    var removeShieldOnAllCalled = false
    var removeShieldOnAllBlockAllPreventsAppDelete: Bool?
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

    func ensureAuthorized() async -> Bool {
        if authorizationState == .authorized { return true }
        await requestAuthorization()
        return authorizationState == .authorized
    }

    func enablePreventAppDelete() { enablePreventAppDeleteCalled = true }
    func disablePreventAppDelete() { disablePreventAppDeleteCalled = true }

    func applyShieldOnAll(selection: FamilyActivitySelection, blockAllPreventsAppDelete: Bool) {
        applyShieldOnAllCalled = true
        applyShieldOnAllSelection = selection
        applyShieldOnAllBlockAllPreventsAppDelete = blockAllPreventsAppDelete
        if blockAllPreventsAppDelete { enablePreventAppDelete() }
    }

    func removeShieldOnAll(blockAllPreventsAppDelete: Bool) {
        removeShieldOnAllCalled = true
        removeShieldOnAllBlockAllPreventsAppDelete = blockAllPreventsAppDelete
        if blockAllPreventsAppDelete { disablePreventAppDelete() }
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
