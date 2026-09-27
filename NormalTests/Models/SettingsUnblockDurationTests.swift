import Foundation
@testable import Normal
import Testing

struct SettingsUnblockDurationTests {
    private func duration(_ seconds: Int) -> TimedUnblockDuration {
        TimedUnblockDuration(validating: seconds)!
    }

    @Test func freshSettingsUsePresetsWithNoDefault() {
        let s = Settings()
        #expect(s.customUnblockDurationSeconds == nil)
        #expect(s.unblockDurations == TimedUnblockDuration.presets)
        #expect(s.defaultDuration == nil)
    }

    @Test(arguments: UnblockDuration.allCases)
    func legacyDefaultIsHonoured(_ legacy: UnblockDuration) {
        let s = Settings()
        s.defaultUnblockDuration = legacy
        #expect(s.defaultDuration?.seconds == legacy.rawValue)
    }

    @Test func settingDefaultClearsLegacyValue() {
        let s = Settings()
        s.defaultUnblockDuration = .oneHour
        s.defaultDuration = .thirtyMinutes
        #expect(s.defaultUnblockDuration == nil)
        #expect(s.defaultDuration == .thirtyMinutes)
    }

    @Test func settingNoneClearsLegacyValue() {
        let s = Settings()
        s.defaultUnblockDuration = .oneHour
        s.defaultDuration = nil
        #expect(s.defaultUnblockDuration == nil)
        #expect(s.defaultDuration == nil, "Choosing None must not fall back to the legacy default")
    }

    @Test func newDefaultWinsOverLegacy() {
        let s = Settings()
        s.defaultUnblockDuration = .oneHour
        s.defaultUnblockSeconds = 1800
        #expect(s.defaultDuration == .thirtyMinutes)
    }

    @Test func defaultNotInListIsIgnored() {
        let s = Settings()
        s.customUnblockDurationSeconds = [900, 1800]
        s.defaultUnblockSeconds = 3600
        #expect(s.defaultDuration == nil)
    }

    @Test func legacyDefaultNotInListIsIgnored() {
        let s = Settings()
        s.customUnblockDurationSeconds = [900]
        s.defaultUnblockDuration = .fourHours
        #expect(s.defaultDuration == nil)
    }

    @Test func addInsertsSorted() {
        let s = Settings()
        #expect(s.addUnblockDuration(duration(5700)) == .added)
        #expect(s.unblockDurations.map(\.seconds) == [900, 1800, 3600, 5700, 14400])
        #expect(s.customUnblockDurationSeconds == [900, 1800, 3600, 5700, 14400])
    }

    @Test func addRejectsDuplicate() {
        let s = Settings()
        #expect(s.addUnblockDuration(.oneHour) == .duplicate)
        #expect(s.customUnblockDurationSeconds == nil, "Nothing written")
    }

    @Test func addRejectsBeyondLimit() {
        let s = Settings()
        let extra = [1200, 2400, 4800, 7200]
        for seconds in extra {
            #expect(s.addUnblockDuration(duration(seconds)) == .added)
        }
        #expect(s.unblockDurations.count == Settings.maxUnblockDurations)
        #expect(s.addUnblockDuration(duration(9000)) == .limitReached)
        #expect(s.unblockDurations.count == Settings.maxUnblockDurations)
    }

    @Test func removeNonDefaultKeepsDefault() {
        let s = Settings()
        s.defaultDuration = .oneHour
        #expect(s.removeUnblockDuration(.fifteenMinutes) == .removed)
        #expect(s.unblockDurations == [.thirtyMinutes, .oneHour, .fourHours])
        #expect(s.defaultDuration == .oneHour)
    }

    @Test func removeDefaultResetsDefaultToNone() {
        let s = Settings()
        s.defaultDuration = .oneHour
        #expect(s.removeUnblockDuration(.oneHour) == .removedDefault)
        #expect(s.defaultDuration == nil)
        #expect(s.defaultUnblockSeconds == nil)
    }

    @Test func removeLegacyDefaultResetsDefaultToNone() {
        let s = Settings()
        s.defaultUnblockDuration = .fourHours
        #expect(s.removeUnblockDuration(.fourHours) == .removedDefault)
        #expect(s.defaultUnblockDuration == nil)
        #expect(s.defaultDuration == nil)
    }

    @Test func readdingDeletedDefaultDoesNotRestoreIt() {
        let s = Settings()
        s.defaultDuration = .oneHour
        s.removeUnblockDuration(.oneHour)
        s.addUnblockDuration(.oneHour)
        #expect(s.defaultDuration == nil)
    }

    @Test func cannotRemoveLastDuration() {
        let s = Settings()
        s.customUnblockDurationSeconds = [1800]
        #expect(s.removeUnblockDuration(.thirtyMinutes) == .lastRemaining)
        #expect(s.unblockDurations == [.thirtyMinutes])
    }

    @Test func presetsCanBeDeleted() {
        let s = Settings()
        s.removeUnblockDuration(.fifteenMinutes)
        #expect(s.customUnblockDurationSeconds == [1800, 3600, 14400])
    }

    @Test func junkStoredListIsSanitizedOnRead() {
        let s = Settings()
        s.customUnblockDurationSeconds = [3600, 3600, 60, 900]
        #expect(s.unblockDurations == [.fifteenMinutes, .oneHour])
    }
}
