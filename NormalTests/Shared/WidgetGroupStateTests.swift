import Foundation
@testable import Normal
import Testing

struct WidgetGroupStateTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func activeTimedUnblockIsUnblockedWithCountdown() {
        let end = now.addingTimeInterval(900)
        let state = WidgetGroupState.resolve(timedUnblockEnd: end, blockStatus: .unblocked, now: now)
        #expect(state == .unblocked(until: end))
        #expect(state.countdownEnd == end)
    }

    @Test func expiredTimedUnblockIsBlockedRegardlessOfMirror() {
        let state = WidgetGroupState.resolve(
            timedUnblockEnd: now.addingTimeInterval(-60),
            blockStatus: .unblocked,
            now: now
        )
        #expect(state == .blocked)
    }

    @Test func noTimedUnblockUsesMirroredShieldState() {
        #expect(WidgetGroupState.resolve(timedUnblockEnd: nil, blockStatus: .unblocked, now: now)
            == .unblocked(until: nil))
        #expect(WidgetGroupState.resolve(timedUnblockEnd: nil, blockStatus: .blocked, now: now) == .blocked)
    }

    @Test func partialBlockCountsAsBlocked() {
        #expect(WidgetGroupState.resolve(timedUnblockEnd: nil, blockStatus: .partial, now: now) == .blocked)
    }

    @Test func unknownMirrorDefaultsToBlocked() {
        #expect(WidgetGroupState.resolve(timedUnblockEnd: nil, blockStatus: nil, now: now) == .blocked)
    }

    @Test func permanentUnblockHasNoCountdown() {
        let state = WidgetGroupState.resolve(timedUnblockEnd: nil, blockStatus: .unblocked, now: now)
        #expect(state.isUnblocked)
        #expect(state.countdownEnd == nil)
    }

    @Test func blockStatusMapsToWidgetBlockStatus() {
        #expect(BlockStatus.all.widget == .blocked)
        #expect(BlockStatus.some.widget == .partial)
        #expect(BlockStatus.none.widget == .unblocked)
    }
}
