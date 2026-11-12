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
        #expect(BlockStatus.all.allowsUnblockAll(mainTimedUnblockActive: false))
        #expect(BlockStatus.some.allowsUnblockAll(mainTimedUnblockActive: false))
        #expect(!BlockStatus.none.allowsUnblockAll(mainTimedUnblockActive: false))
        #expect(!BlockStatus.all.allowsUnblockAll(mainTimedUnblockActive: true))
    }

    @Test func groupTimerShowsUnlessFullyBlockedElsewhere() {
        #expect(BlockStatus.some.showsGroupTimedUnblock(groupTimedUnblockActive: true))
        #expect(BlockStatus.none.showsGroupTimedUnblock(groupTimedUnblockActive: true))
        #expect(!BlockStatus.all.showsGroupTimedUnblock(groupTimedUnblockActive: true))
        #expect(!BlockStatus.some.showsGroupTimedUnblock(groupTimedUnblockActive: false))
    }

    @Test func authorizationStateEquatable() {
        #expect(AuthorizationState.authorized == .authorized)
        #expect(AuthorizationState.notAuthorized == .notAuthorized)
        #expect(AuthorizationState.authorized != .notAuthorized)
    }
}
