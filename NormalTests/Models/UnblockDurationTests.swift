@testable import Normal
import Testing

struct UnblockDurationTests {
    @Test func timeIntervalValues() {
        #expect(UnblockDuration.fifteenMinutes.timeInterval == 900)
        #expect(UnblockDuration.thirtyMinutes.timeInterval == 1800)
        #expect(UnblockDuration.oneHour.timeInterval == 3600)
        #expect(UnblockDuration.twoHours.timeInterval == 7200)
    }

    @Test func labels() {
        #expect(UnblockDuration.fifteenMinutes.label == "15 Minutes")
        #expect(UnblockDuration.thirtyMinutes.label == "30 Minutes")
        #expect(UnblockDuration.oneHour.label == "1 Hour")
        #expect(UnblockDuration.twoHours.label == "2 Hours")
    }

    @Test func allCasesCount() {
        #expect(UnblockDuration.allCases.count == 4)
    }
}
