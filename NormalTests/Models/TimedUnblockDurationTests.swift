import Foundation
@testable import Normal
import Testing

struct TimedUnblockDurationTests {
    @Test(arguments: [900, 1200, 5700, 86100])
    func acceptsValidSeconds(_ seconds: Int) {
        #expect(TimedUnblockDuration(validating: seconds)?.seconds == seconds)
    }

    @Test(arguments: [-900, 0, 60, 899, 1000, 86101, 86400, 90000])
    func rejectsInvalidSeconds(_ seconds: Int) {
        #expect(TimedUnblockDuration(validating: seconds) == nil)
    }

    @Test func hoursAndMinutesInitializer() {
        #expect(TimedUnblockDuration(hours: 1, minutes: 35)?.seconds == 5700)
        #expect(TimedUnblockDuration(hours: 23, minutes: 55)?.seconds == TimedUnblockDuration.maximumSeconds)
        #expect(TimedUnblockDuration(hours: 0, minutes: 10) == nil, "Below the 15 minute minimum")
    }

    @Test func hoursAndMinutesComponents() throws {
        let duration = try #require(TimedUnblockDuration(validating: 5700))
        #expect(duration.hours == 1)
        #expect(duration.minutes == 35)
        #expect(duration.timeInterval == 5700)
    }

    @Test func presetsMatchLegacyEnumOneToOne() {
        #expect(TimedUnblockDuration.presets.map(\.seconds) == UnblockDuration.allCases.map(\.rawValue))
    }

    @Test func presetsAreValid() {
        for preset in TimedUnblockDuration.presets {
            #expect(TimedUnblockDuration.isValid(preset.seconds))
        }
    }

    @Test func sortsByLength() throws {
        let long = try #require(TimedUnblockDuration(validating: 7200))
        #expect([long, .fifteenMinutes, .oneHour].sorted() == [.fifteenMinutes, .oneHour, long])
    }

    @Test func sanitizedNilFallsBackToPresets() {
        #expect(TimedUnblockDuration.sanitized(nil) == TimedUnblockDuration.presets)
    }

    @Test func sanitizedDropsJunkDedupesAndSorts() {
        let result = TimedUnblockDuration.sanitized([3600, 60, 900, 3600, 1000, 86400])
        #expect(result == [.fifteenMinutes, .oneHour])
    }

    @Test func sanitizedAllInvalidFallsBackToPresets() {
        #expect(TimedUnblockDuration.sanitized([]) == TimedUnblockDuration.presets)
        #expect(TimedUnblockDuration.sanitized([1, 2]) == TimedUnblockDuration.presets)
    }

    @Test(arguments: [900, 3600, 5700, 86100])
    func labelIsNonEmpty(_ seconds: Int) throws {
        let duration = try #require(TimedUnblockDuration(validating: seconds))
        #expect(!duration.label.isEmpty)
    }

    @Test func labelsAreDistinct() {
        let labels = TimedUnblockDuration.presets.map(\.label)
        #expect(Set(labels).count == labels.count)
    }
}

struct UnlockDurationRequestTests {
    @Test func missingValueUsesDefault() {
        #expect(UnlockDurationRequest(queryValue: nil) == .useDefault)
    }

    @Test func askValueAsks() {
        #expect(UnlockDurationRequest(queryValue: "ask") == .ask)
    }

    @Test func validSecondsAreFixedEvenIfNotAPreset() throws {
        let custom = try #require(TimedUnblockDuration(validating: 5700))
        #expect(UnlockDurationRequest(queryValue: "5700") == .fixed(custom))
    }

    @Test(arguments: ["999", "60", "90000", "+900", "-900", "abc", ""])
    func invalidValuesFallBackToAsking(_ value: String) {
        #expect(UnlockDurationRequest(queryValue: value) == .ask)
    }

    @Test func queryValueRoundTrips() throws {
        let custom = try #require(TimedUnblockDuration(validating: 5700))
        for request in [UnlockDurationRequest.useDefault, .ask, .fixed(custom)] {
            #expect(UnlockDurationRequest(queryValue: request.queryValue) == request)
        }
    }
}
