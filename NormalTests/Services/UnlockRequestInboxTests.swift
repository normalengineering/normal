import Foundation
@testable import Normal
import Testing

@MainActor
struct UnlockRequestInboxTests {
    private final class TestClock {
        var now = Date()
    }

    @Test func takeReturnsThePostedRequestOnce() {
        let inbox = UnlockRequestInbox()
        let groupID = UUID()

        inbox.post(groupID: groupID, duration: .fixed(.oneHour), keyType: .nfc)
        let request = inbox.take()

        #expect(request?.groupID == groupID)
        #expect(request?.duration == .fixed(.oneHour))
        #expect(request?.keyType == .nfc)
        #expect(inbox.pending == nil)
        #expect(inbox.take() == nil)
    }

    @Test func newerRequestReplacesOlder() {
        let inbox = UnlockRequestInbox()

        inbox.post(groupID: UUID(), duration: .ask, keyType: .qr)
        inbox.post(groupID: nil, duration: .useDefault, keyType: nil)

        let request = inbox.take()
        #expect(request != nil)
        #expect(request?.groupID == nil)
        #expect(request?.duration == .useDefault)
    }

    @Test func staleRequestIsDropped() {
        let clock = TestClock()
        let inbox = UnlockRequestInbox(clock: { clock.now })

        inbox.post(groupID: nil, duration: .ask, keyType: .nfc)
        clock.now = clock.now.addingTimeInterval(UnlockRequestInbox.lifetime + 1)

        #expect(inbox.take() == nil)
        #expect(inbox.pending == nil)
    }
}
