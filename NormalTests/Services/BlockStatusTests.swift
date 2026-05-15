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

    @Test func authorizationStateEquatable() {
        #expect(AuthorizationState.authorized == .authorized)
        #expect(AuthorizationState.notAuthorized == .notAuthorized)
        #expect(AuthorizationState.authorized != .notAuthorized)
    }
}
