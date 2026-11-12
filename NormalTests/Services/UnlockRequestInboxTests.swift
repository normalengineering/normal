import Foundation
@testable import Normal
import Testing

@MainActor
struct UnlockRequestInboxTests {
    private final class TestClock {
        var now = Date()
    }

    private let request = UnblockRequest(groupID: UUID(), duration: .fixed(.oneHour), keyType: .nfc)

    @Test func takeReturnsThePostedRequestOnce() {
        let inbox = UnlockRequestInbox()

        inbox.post(request)

        #expect(inbox.take() == request)
        #expect(inbox.pending == nil)
        #expect(inbox.take() == nil)
    }

    @Test func newerRequestReplacesOlder() {
        let inbox = UnlockRequestInbox()
        let newer = UnblockRequest(groupID: nil, duration: .useDefault, keyType: nil)

        inbox.post(request)
        inbox.post(newer)

        #expect(inbox.take() == newer)
    }

    @Test func requestIsKeptForItsLifetime() {
        let clock = TestClock()
        let inbox = UnlockRequestInbox(clock: { clock.now })

        inbox.post(request)
        clock.now = clock.now.addingTimeInterval(UnlockRequestInbox.lifetime)

        #expect(inbox.take() == request)
    }

    @Test func staleRequestIsDropped() {
        let clock = TestClock()
        let inbox = UnlockRequestInbox(clock: { clock.now })

        inbox.post(request)
        clock.now = clock.now.addingTimeInterval(UnlockRequestInbox.lifetime + 1)

        #expect(inbox.take() == nil)
        #expect(inbox.pending == nil)
    }
}
