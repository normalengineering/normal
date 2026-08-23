import FamilyControls
import Foundation
@testable import Normal
import Testing

/// The floor is the feature's safety net: shields must never drop below the
/// limits already spent today, whichever unblock path lifted them.
@MainActor
struct UsageFloorTests {
    private let day = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func makeService(
        store: FakeSharedStore
    ) -> (ScreenTimeService, InMemoryShieldStore) {
        let shield = InMemoryShieldStore()
        let service = ScreenTimeService(
            defaults: UserDefaults(suiteName: "usage-floor-\(UUID().uuidString)")!,
            shield: shield,
            sharedStore: store
        )
        return (service, shield)
    }

    private func storeWithReachedLimit() -> FakeSharedStore {
        let store = FakeSharedStore()
        let id = UUID()
        store.usageLimits = [
            UsageLimitDTO(
                id: id,
                selectionData: (try? FamilyActivitySelection().toData()) ?? Data(),
                minutesPerDay: 30
            ),
        ]
        store.usageDayState = UsageDayStateDTO
            .fresh(on: .now)
            .recording(.reached, for: id, on: .now)
        return store
    }

    @Test func unblockingAllLeavesASpentLimitShielded() {
        let store = storeWithReachedLimit()
        let (service, shield) = makeService(store: store)
        shield.union(with: FamilyActivitySelection(), customDomains: [])

        service.removeShieldOnAll(blockAllPreventsAppDelete: true)

        #expect(shield.shieldedCount() > 0)
    }

    /// Re-shielding without restoring the flag leaves the app deletable while
    /// blocks are in force — the exact hole the setting exists to close.
    @Test func theFloorRestoresPreventAppDelete() {
        let store = storeWithReachedLimit()
        let (service, shield) = makeService(store: store)

        service.removeShieldOnAll(blockAllPreventsAppDelete: true)

        #expect(shield.denyAppRemoval)
    }

    @Test func aLimitSurvivesAnUnblockAll() {
        let store = storeWithReachedLimit()
        let (service, shield) = makeService(store: store)

        service.removeShieldOnAll(blockAllPreventsAppDelete: false)

        #expect(shield.shieldedCount() > 0)
    }

    @Test func aPartialUnblockAlsoHonoursTheFloor() {
        let store = storeWithReachedLimit()
        let (service, shield) = makeService(store: store)

        service.removeFromShields(selection: FamilyActivitySelection(), customDomains: [])

        #expect(shield.shieldedCount() > 0)
    }

    @Test func nothingIsRestoredWhenNoLimitIsSpent() {
        let (service, shield) = makeService(store: FakeSharedStore())
        shield.union(with: FamilyActivitySelection(), customDomains: [])

        service.removeShieldOnAll(blockAllPreventsAppDelete: true)

        #expect(shield.shieldedCount() == 0)
        #expect(shield.denyAppRemoval == false)
    }

    /// An emergency unblock outranks the caps, so the floor must stand down —
    /// otherwise it silently undoes an unblock rationed to three per 180 days.
    @Test func anEmergencyOverrideStandsTheFloorDown() {
        let store = storeWithReachedLimit()
        store.overrideUsageDay()
        let (service, shield) = makeService(store: store)

        service.removeShieldOnAll(blockAllPreventsAppDelete: true)

        #expect(shield.shieldedCount() == 0)
    }
}
