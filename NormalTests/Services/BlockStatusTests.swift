@testable import Normal
import Testing

struct BlockStatusTests {
    @Test func shortLabels() {
        #expect(BlockStatus.all.shortLabel == "Blocked")
        #expect(BlockStatus.some.shortLabel == "Partial")
        #expect(BlockStatus.none.shortLabel == "Unblocked")
    }

    @Test func titlesAreReadable() {
        #expect(!BlockStatus.all.title.isEmpty)
        #expect(!BlockStatus.some.title.isEmpty)
        #expect(!BlockStatus.none.title.isEmpty)
    }

    @Test func iconsAreSet() {
        #expect(!BlockStatus.all.icon.isEmpty)
        #expect(!BlockStatus.some.icon.isEmpty)
        #expect(!BlockStatus.none.icon.isEmpty)
    }

    @Test func unblockAllNeedsABlockAndNoActiveTimer() {
        #expect(BlockStatus.all.canUnblockAll(timedUnblockActive: false))
        #expect(BlockStatus.some.canUnblockAll(timedUnblockActive: false))
        #expect(!BlockStatus.none.canUnblockAll(timedUnblockActive: false))
        #expect(!BlockStatus.all.canUnblockAll(timedUnblockActive: true))
    }

    @Test func groupTimerShowsUnlessFullyBlockedElsewhere() {
        #expect(BlockStatus.some.showsGroupTimedUnblock(timedUnblockActive: true))
        #expect(BlockStatus.none.showsGroupTimedUnblock(timedUnblockActive: true))
        #expect(!BlockStatus.all.showsGroupTimedUnblock(timedUnblockActive: true))
        #expect(!BlockStatus.some.showsGroupTimedUnblock(timedUnblockActive: false))
    }

    @Test func groupCanBeUnblockedWhenBlockedWithoutATimer() {
        #expect(BlockStatus.some.canUnblockGroup(timedUnblockActive: false))
        #expect(BlockStatus.all.canUnblockGroup(timedUnblockActive: true))
        #expect(!BlockStatus.some.canUnblockGroup(timedUnblockActive: true))
        #expect(!BlockStatus.none.canUnblockGroup(timedUnblockActive: false))
    }

    @Test func authorizationStateEquatable() {
        #expect(AuthorizationState.authorized == .authorized)
        #expect(AuthorizationState.notAuthorized == .notAuthorized)
        #expect(AuthorizationState.authorized != .notAuthorized)
    }
}
