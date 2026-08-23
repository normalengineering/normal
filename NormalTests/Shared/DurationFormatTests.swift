@testable import Normal
import Testing

struct DurationFormatTests {
    @Test func compactDropsTheEmptyComponent() {
        #expect(DurationFormat.compact(minutes: 0) == "0m")
        #expect(DurationFormat.compact(minutes: 45) == "45m")
        #expect(DurationFormat.compact(minutes: 60) == "1h")
        #expect(DurationFormat.compact(minutes: 90) == "1h 30m")
        #expect(DurationFormat.compact(minutes: 120) == "2h")
    }

    @Test func compactHandlesTheLongestAllowedLimit() {
        #expect(DurationFormat.compact(minutes: UsageLimit.maximumMinutes) == "23h 55m")
    }

    @Test func spelledUsesWordsAndPluralisesThem() {
        #expect(DurationFormat.spelled(minutes: 1).contains("1"))
        #expect(DurationFormat.spelled(minutes: 90).contains("hour"))
        #expect(DurationFormat.spelled(minutes: 45).contains("minute"))
        // Zero-valued components are hidden rather than printed as "0 hours".
        #expect(DurationFormat.spelled(minutes: 60).contains("minute") == false)
    }
}
