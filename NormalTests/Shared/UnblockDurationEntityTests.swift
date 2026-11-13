@testable import Normal
import Testing

struct UnblockDurationEntityTests {
    @Test func savedWidgetIDsKeepTheirMeaning() {
        #expect(UnblockDurationEntity(id: -1).request == .useDefault)
        #expect(UnblockDurationEntity(id: 0).request == .ask)
        #expect(UnblockDurationEntity(id: 3600).request == .fixed(.oneHour))
    }

    @Test func everyRequestRoundTripsThroughItsID() throws {
        let custom = try #require(TimedUnblockDuration(validating: 5700))
        for request in [UnlockDurationRequest.useDefault, .ask, .fixed(custom), .permanent] {
            #expect(UnblockDurationEntity(request).request == request)
        }
    }

    @Test(arguments: [-3, 60, 999, 90000])
    func invalidIDsDoNotResolve(_ id: Int) {
        #expect(UnblockDurationEntity.request(forID: id) == nil)
    }
}
