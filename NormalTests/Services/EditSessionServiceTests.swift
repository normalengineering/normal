import Foundation
import Testing

@testable import Normal

@MainActor
struct EditSessionServiceTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private func makeService(
        defaults: UserDefaults? = nil,
        clock: Clock = Clock()
    ) -> (service: EditSessionService, defaults: UserDefaults, clock: Clock) {
        let suite = defaults ?? UserDefaults(suiteName: "edit-session-test-\(UUID().uuidString)")!
        return (EditSessionService(defaults: suite, clock: { clock.now }), suite, clock)
    }

    private var globalKey: Key {
        Key(name: "Desk", type: .qr, rawValue: "GLOBAL")
    }

    private func groupKey(groupID: UUID = UUID()) -> Key {
        Key(name: "Social", type: .qr, rawValue: "GROUP", groupID: groupID)
    }

    @Test func startsBlockedByDefault() {
        let (service, _, _) = makeService()
        #expect(!service.isActive)
        #expect(service.state == .blocked)
        #expect(service.endDate == nil)
        #expect(!service.isPermanent)
    }

    @Test func timedUnblockActivatesPersistsAndExpiresWhenClockAdvances() {
        let (service, defaults, clock) = makeService()
        let start = clock.now

        service.unblock(for: .timed(.fifteenMinutes), proof: KeyProof(keyGroupID: nil))

        #expect(service.isActive)
        #expect(!service.isPermanent)
        #expect(service.endDate == start.addingTimeInterval(.minutes(15)))

        let restored = EditSessionService(defaults: defaults, clock: { clock.now })
        #expect(restored.isActive)
        #expect(restored.endDate == service.endDate)

        clock.now = start.addingTimeInterval(.minutes(15))
        #expect(!service.isActive)
        service.refresh()
        #expect(service.state == .blocked)

        let afterExpiry = EditSessionService(defaults: defaults, clock: { clock.now })
        #expect(!afterExpiry.isActive)
        #expect(afterExpiry.state == .blocked)
    }

    @Test func permanentUnblockPersistsUntilManuallyBlocked() {
        let (service, defaults, clock) = makeService()

        service.unblock(for: .permanent, proof: KeyProof(keyGroupID: nil))

        #expect(service.isActive)
        #expect(service.isPermanent)
        #expect(service.endDate == nil)

        clock.now = clock.now.addingTimeInterval(.days(7))
        let restored = EditSessionService(defaults: defaults, clock: { clock.now })
        #expect(restored.isActive)
        #expect(restored.isPermanent)

        restored.block()
        #expect(!restored.isActive)
        #expect(restored.state == .blocked)
        #expect(!EditSessionService(defaults: defaults, clock: { clock.now }).isActive)
    }

    @Test func rejectsGroupScopedKeyProof() {
        let (service, _, _) = makeService()

        service.unblock(for: .timed(.fifteenMinutes), proof: KeyProof(keyGroupID: UUID()))
        #expect(!service.isActive)

        service.unblock(for: .permanent, proof: KeyProof(keyGroupID: UUID()))
        #expect(!service.isActive)
    }

    @Test func emergencyAccessUnblocksEditingWithoutAKeyProof() {
        let (service, defaults, clock) = makeService()

        service.grantEmergencyAccess()

        #expect(service.isActive)
        #expect(service.isPermanent)
        #expect(EditSessionService(defaults: defaults, clock: { clock.now }).isActive)
    }

    @Test func requireKeyBlocksEditingWithGlobalKeyEvenWhenNoAppsAreBlocked() {
        let (service, _, _) = makeService()
        let keys = [globalKey]

        #expect(service.isEditingBlocked(mode: .requireKey, keys: keys, activeShieldCount: 0))
        #expect(service.isEditingBlocked(mode: .requireKey, keys: keys, activeShieldCount: 3))

        service.unblock(for: .timed(.fifteenMinutes), proof: KeyProof(keyGroupID: nil))

        #expect(!service.isEditingBlocked(mode: .requireKey, keys: keys, activeShieldCount: 0))
        #expect(!service.isEditingBlocked(mode: .requireKey, keys: keys, activeShieldCount: 3))
    }

    @Test func requireKeyAllowsEditingWithZeroKeysAndBlocksGroupKeyOnlyWhileShielded() {
        let (service, _, _) = makeService()

        #expect(!service.isEditingBlocked(mode: .requireKey, keys: [], activeShieldCount: 0))
        #expect(!service.isEditingBlocked(mode: .requireKey, keys: [], activeShieldCount: 2))

        let onlyGroupKey = [groupKey()]
        #expect(!service.isEditingBlocked(mode: .requireKey, keys: onlyGroupKey, activeShieldCount: 0))
        #expect(service.isEditingBlocked(mode: .requireKey, keys: onlyGroupKey, activeShieldCount: 1))
    }

    @Test func unblockAllModeDependsOnlyOnActiveShields() {
        let (service, _, _) = makeService()
        let keys = [globalKey]

        #expect(!service.isEditingBlocked(mode: .unblockAll, keys: keys, activeShieldCount: 0))
        #expect(service.isEditingBlocked(mode: .unblockAll, keys: keys, activeShieldCount: 1))
        #expect(!service.isEditingBlocked(mode: .unblockAll, keys: [], activeShieldCount: 1, allowWhenNoKeys: true))
        #expect(service.isEditingBlocked(mode: .unblockAll, keys: [], activeShieldCount: 1, allowWhenNoKeys: false))
    }

    @Test func modeChangeOnlyRequiresKeyWhenDowngradingWithoutAnActiveSession() {
        let (service, _, _) = makeService()
        let keys = [globalKey]

        #expect(service.requiresKeyToChangeMode(from: .requireKey, to: .unblockAll, keys: keys))
        #expect(!service.requiresKeyToChangeMode(from: .unblockAll, to: .requireKey, keys: keys))
        #expect(!service.requiresKeyToChangeMode(from: .requireKey, to: .unblockAll, keys: []))

        service.unblock(for: .timed(.fifteenMinutes), proof: KeyProof(keyGroupID: nil))
        #expect(!service.requiresKeyToChangeMode(from: .requireKey, to: .unblockAll, keys: keys))
    }

    @Test func unsupportedDeviceKeysAllowEditingWhenUnblockedButBlockWhenShielded() {
        let (service, _, _) = makeService()
        let nfcOnly = [Key(name: "Tag", type: .nfc, rawValue: "NFC")]
        let ipadCapabilities: [KeyType] = [.qr, .location]

        #expect(
            !service.isEditingBlocked(
                mode: .requireKey,
                keys: nfcOnly,
                activeShieldCount: 0,
                availableKeyTypes: ipadCapabilities
            ))
        #expect(
            service.isEditingBlocked(
                mode: .requireKey,
                keys: nfcOnly,
                activeShieldCount: 2,
                availableKeyTypes: ipadCapabilities
            ))
        #expect(
            !service.requiresKeyToChangeMode(
                from: .requireKey,
                to: .unblockAll,
                keys: nfcOnly,
                activeShieldCount: 0,
                availableKeyTypes: ipadCapabilities
            ))
        #expect(
            service.requiresKeyToChangeMode(
                from: .requireKey,
                to: .unblockAll,
                keys: nfcOnly,
                activeShieldCount: 2,
                availableKeyTypes: ipadCapabilities
            ))
    }
}
