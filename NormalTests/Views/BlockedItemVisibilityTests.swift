import Foundation
@testable import Normal
import Testing

@MainActor
struct BlockedItemVisibilityTests {
    private static let blocked: Set<String> = ["mail", "news"]

    private func visible(_ items: [String], hideBlocked: Bool) -> [String] {
        BlockedItemVisibility(hideBlocked: hideBlocked).visible(items) { Self.blocked.contains($0) }
    }

    private func hiddenCount(_ items: [String], hideBlocked: Bool) -> Int {
        BlockedItemVisibility(hideBlocked: hideBlocked).hiddenCount(items) { Self.blocked.contains($0) }
    }

    @Test func showsEverythingWhenDisabled() {
        let items = ["mail", "maps", "news"]
        #expect(visible(items, hideBlocked: false) == items)
    }

    @Test func hidesBlockedItemsWhenEnabled() {
        #expect(visible(["mail", "maps", "news"], hideBlocked: true) == ["maps"])
    }

    @Test func preservesOrderOfRemainingItems() {
        let items = ["maps", "mail", "phone", "news", "photos"]
        #expect(visible(items, hideBlocked: true) == ["maps", "phone", "photos"])
    }

    @Test func hidesNothingWhenNoItemIsBlocked() {
        let items = ["maps", "phone"]
        #expect(visible(items, hideBlocked: true) == items)
        #expect(hiddenCount(items, hideBlocked: true) == 0)
    }

    @Test func hidesEverythingWhenAllItemsAreBlocked() {
        let items = ["mail", "news"]
        #expect(visible(items, hideBlocked: true).isEmpty)
        #expect(hiddenCount(items, hideBlocked: true) == 2)
    }

    @Test func hiddenCountIsZeroWhenDisabled() {
        #expect(hiddenCount(["mail", "news"], hideBlocked: false) == 0)
    }

    @Test func hiddenCountCountsOnlyBlockedItems() {
        #expect(hiddenCount(["mail", "maps", "news"], hideBlocked: true) == 2)
    }

    @Test func emptyInputStaysEmpty() {
        #expect(visible([], hideBlocked: true).isEmpty)
        #expect(hiddenCount([], hideBlocked: true) == 0)
    }
}
