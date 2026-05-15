@testable import Normal
import Foundation
import Testing

struct SortIndexingTests {
    private final class Item: Reorderable {
        let id: Int
        var sortIndex: Int
        init(id: Int, sortIndex: Int) {
            self.id = id
            self.sortIndex = sortIndex
        }
    }

    private func makeItems(_ count: Int) -> [Item] {
        (0 ..< count).map { Item(id: $0, sortIndex: $0) }
    }

    // MARK: - reorder

    @Test func moveDownAssignsContiguousIndices() {
        let items = makeItems(4)
        // Move item at index 0 to position after index 2 (destination = 3)
        let result = SortIndexing.reorder(items, from: IndexSet(integer: 0), to: 3)

        #expect(result.map(\.id) == [1, 2, 0, 3])
        #expect(result.map(\.sortIndex) == [0, 1, 2, 3])
        // The moved item's sortIndex updated in place
        #expect(items[0].sortIndex == 2)
    }

    @Test func moveUpAssignsContiguousIndices() {
        let items = makeItems(4)
        // Move item at index 3 to position 0
        let result = SortIndexing.reorder(items, from: IndexSet(integer: 3), to: 0)

        #expect(result.map(\.id) == [3, 0, 1, 2])
        #expect(result.map(\.sortIndex) == [0, 1, 2, 3])
        #expect(items[3].sortIndex == 0)
    }

    @Test func noOpMoveStillNormalizesIndices() {
        let items = [
            Item(id: 0, sortIndex: 5),
            Item(id: 1, sortIndex: 9),
            Item(id: 2, sortIndex: 14)
        ]
        // No-op move: source 0, destination 0
        let result = SortIndexing.reorder(items, from: IndexSet(integer: 0), to: 0)

        #expect(result.map(\.id) == [0, 1, 2])
        #expect(result.map(\.sortIndex) == [0, 1, 2])
    }

    @Test func multiSelectMovePreservesRelativeOrder() {
        let items = makeItems(5) // [0, 1, 2, 3, 4]
        // Move items at index 0 and 2 to after index 4 (destination = 5)
        let result = SortIndexing.reorder(items, from: IndexSet([0, 2]), to: 5)

        // Remaining items 1, 3, 4 stay in order; moved items 0, 2 come after
        #expect(result.map(\.id) == [1, 3, 4, 0, 2])
        #expect(result.map(\.sortIndex) == [0, 1, 2, 3, 4])
    }

    @Test func singleItemReorderIsIdempotent() {
        let items = [Item(id: 7, sortIndex: 42)]
        let result = SortIndexing.reorder(items, from: IndexSet(integer: 0), to: 0)

        #expect(result.count == 1)
        #expect(result[0].id == 7)
        #expect(result[0].sortIndex == 0)
    }

    @Test func reorderReturnsSameInstances() {
        let items = makeItems(3)
        let result = SortIndexing.reorder(items, from: IndexSet(integer: 0), to: 2)

        // Returned array contains the same object references — mutations to them
        // reflect in the original items array.
        for item in items {
            #expect(result.contains(where: { $0 === item }))
        }
    }

    // MARK: - nextIndex

    @Test func nextIndexOfEmptyArrayIsZero() {
        let empty: [Item] = []
        #expect(SortIndexing.nextIndex(after: empty) == 0)
    }

    @Test func nextIndexIsMaxPlusOne() {
        let items = [
            Item(id: 0, sortIndex: 0),
            Item(id: 1, sortIndex: 5),
            Item(id: 2, sortIndex: 2)
        ]
        #expect(SortIndexing.nextIndex(after: items) == 6)
    }

    @Test func nextIndexIgnoresGapsAndUsesMax() {
        let items = [
            Item(id: 0, sortIndex: 0),
            Item(id: 1, sortIndex: 100),
            Item(id: 2, sortIndex: 1)
        ]
        #expect(SortIndexing.nextIndex(after: items) == 101)
    }

    @Test func nextIndexWorksWithNegativeValues() {
        let items = [Item(id: 0, sortIndex: -3)]
        #expect(SortIndexing.nextIndex(after: items) == -2)
    }
}
