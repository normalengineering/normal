import FamilyControls
import Foundation
import Testing

@testable import Normal

struct GroupUnblockDefaultsTests {
    private let settings = Settings()
    private let group = AppGroup(name: "Social", selection: FamilyActivitySelection())

    @Test func groupsFollowTheAppDefaultsUntilChanged() {
        settings.defaultDuration = .thirtyMinutes
        settings.defaultKeyType = .nfc

        #expect(group.durationOverride == .appDefault)
        #expect(group.keyOverride == .appDefault)
        #expect(settings.defaultDuration(for: group) == .thirtyMinutes)
        #expect(settings.defaultKeyType(for: group) == .nfc)
        #expect(settings.unblockLength(for: .useDefault, group: group) == .timed(.thirtyMinutes))
    }

    @Test func groupDurationOverridesTheAppDefault() {
        settings.defaultDuration = .thirtyMinutes
        group.durationOverride = .value(.oneHour)

        #expect(settings.defaultDuration(for: group) == .oneHour)
        #expect(settings.unblockLength(for: .useDefault, group: group) == .timed(.oneHour))
        #expect(settings.defaultDuration(for: nil) == .thirtyMinutes, "Unblock All keeps the app default")
    }

    @Test func groupDurationWorksWithoutAnAppDefault() {
        group.durationOverride = .value(.fourHours)

        #expect(settings.defaultDuration == nil)
        #expect(settings.defaultDuration(for: group) == .fourHours)
    }

    @Test func groupCanTurnOffTheAppDefaultDuration() {
        settings.defaultDuration = .thirtyMinutes
        group.durationOverride = .none

        #expect(settings.defaultDuration(for: group) == nil)
        #expect(settings.unblockLength(for: .useDefault, group: group) == nil)
    }

    @Test func groupDurationRemovedFromTheListAsksInsteadOfUsingTheAppDefault() {
        settings.defaultDuration = .thirtyMinutes
        group.durationOverride = .value(.fourHours)

        settings.removeUnblockDuration(.fourHours)

        #expect(settings.defaultDuration(for: group) == nil)
    }

    @Test func requestedDurationsIgnoreTheGroupDefault() {
        group.durationOverride = .value(.oneHour)

        #expect(settings.unblockLength(for: .fixed(.fifteenMinutes), group: group) == .timed(.fifteenMinutes))
        #expect(settings.unblockLength(for: .permanent, group: group) == .permanent)
        #expect(settings.unblockLength(for: .ask, group: group) == nil)
    }

    @Test func groupKeyOverridesTheAppDefaultKey() {
        settings.defaultKeyType = .nfc

        group.keyOverride = .value(.location)
        #expect(settings.defaultKeyType(for: group) == .location)

        group.keyOverride = .none
        #expect(settings.defaultKeyType(for: group) == nil)
        #expect(settings.defaultKeyType(for: nil) == .nfc, "Unblock All keeps the app default")
    }

    @Test func choosingAppDefaultAgainClearsTheOverride() {
        group.durationOverride = .value(.oneHour)
        group.keyOverride = .value(.qr)

        group.durationOverride = .appDefault
        group.keyOverride = .appDefault

        #expect(!group.overridesDefaultDuration)
        #expect(group.defaultUnblockSeconds == nil)
        #expect(!group.overridesDefaultKey)
        #expect(group.defaultKeyType == nil)
    }
}
