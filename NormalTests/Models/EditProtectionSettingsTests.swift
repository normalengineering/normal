import Foundation
import Testing

@testable import Normal

@MainActor
struct EditProtectionSettingsTests {
    @Test func editProtectionDefaultsToRequireKeyAndInheritsAppDefaults() {
        let settings = Settings()
        settings.defaultDuration = .thirtyMinutes
        settings.defaultKeyType = .nfc

        #expect(settings.editProtectionMode == .requireKey)
        #expect(settings.editDurationOverride == .appDefault)
        #expect(settings.editKeyOverride == .appDefault)
        #expect(settings.resolvedEditDefaultDuration == .thirtyMinutes)
        #expect(settings.resolvedEditDefaultKeyType == .nfc)
    }

    @Test func explicitNoneOverridesAppDefaultsToAsk() {
        let settings = Settings()
        settings.defaultDuration = .oneHour
        settings.defaultKeyType = .qr

        settings.editDurationOverride = .none
        settings.editKeyOverride = .none

        #expect(settings.resolvedEditDefaultDuration == nil)
        #expect(settings.resolvedEditDefaultKeyType == nil)
    }

    @Test func explicitDurationOverrideResolvesAndDropsToAskWhenRemoved() {
        let settings = Settings()
        settings.defaultDuration = .fifteenMinutes
        settings.editDurationOverride = .value(.fourHours)

        #expect(settings.resolvedEditDefaultDuration == .fourHours)

        settings.removeUnblockDuration(.fourHours)

        #expect(settings.resolvedEditDefaultDuration == nil)
    }

    @Test func editUnlockGrantRequiresGlobalKeyProof() {
        #expect(EditUnlockGrant(proof: KeyProof(keyGroupID: nil)) != nil)
        #expect(EditUnlockGrant(proof: KeyProof(keyGroupID: UUID())) == nil)
    }
}
