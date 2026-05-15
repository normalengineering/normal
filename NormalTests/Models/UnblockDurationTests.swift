@testable import Normal
import Testing

struct UnblockDurationTests {
    @Test func fifteenMinutesEquals900Seconds() {
        #expect(UnblockDuration.fifteenMinutes.timeInterval == 900)
    }

    @Test func oneHourEquals3600Seconds() {
        #expect(UnblockDuration.oneHour.timeInterval == 3600)
    }

    @Test func twoHoursEquals7200Seconds() {
        #expect(UnblockDuration.twoHours.timeInterval == 7200)
    }

    @Test func idEqualsRawValue() {
        #expect(UnblockDuration.thirtyMinutes.id == 1800)
    }

    @Test func allCasesAreUnique() {
        let raws = UnblockDuration.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    @Test func labelsAreNonEmpty() {
        for d in UnblockDuration.allCases {
            #expect(!d.label.isEmpty)
        }
    }
}
