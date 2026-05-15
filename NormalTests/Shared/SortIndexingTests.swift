import Foundation
@testable import Normal
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

    @Test func moveDownAssignsContiguousIndices() {
        let items = makeItems(4)
        let result = SortIndexing.reorder(items, from: IndexSet(integer: 0), to: 3)

        #expect(result.map(\.id) == [1, 2, 0, 3])
        #expect(result.map(\.sortIndex) == [0, 1, 2, 3])
        #expect(items[0].sortIndex == 2)
    }

    @Test func moveUpAssignsContiguousIndices() {
        let items = makeItems(4)
        let result = SortIndexing.reorder(items, from: IndexSet(integer: 3), to: 0)

        #expect(result.map(\.id) == [3, 0, 1, 2])
        #expect(result.map(\.sortIndex) == [0, 1, 2, 3])
        #expect(items[3].sortIndex == 0)
    }

    @Test func noOpMoveStillNormalizesIndices() {
        let items = [
            Item(id: 0, sortIndex: 5),
            Item(id: 1, sortIndex: 9),
            Item(id: 2, sortIndex: 14),
        ]
        let result = SortIndexing.reorder(items, from: IndexSet(integer: 0), to: 0)

        #expect(result.map(\.id) == [0, 1, 2])
        #expect(result.map(\.sortIndex) == [0, 1, 2])
    }

    @Test func multiSelectMovePreservesRelativeOrder() {
        let items = makeItems(5)
        let result = SortIndexing.reorder(items, from: IndexSet([0, 2]), to: 5)

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

        for item in items {
            #expect(result.contains(where: { $0 === item }))
        }
    }

    @Test func nextIndexOfEmptyArrayIsZero() {
        let empty: [Item] = []
        #expect(SortIndexing.nextIndex(after: empty) == 0)
    }

    @Test func nextIndexIsMaxPlusOne() {
        let items = [
            Item(id: 0, sortIndex: 0),
            Item(id: 1, sortIndex: 5),
            Item(id: 2, sortIndex: 2),
        ]
        #expect(SortIndexing.nextIndex(after: items) == 6)
    }

    @Test func nextIndexIgnoresGapsAndUsesMax() {
        let items = [
            Item(id: 0, sortIndex: 0),
            Item(id: 1, sortIndex: 100),
            Item(id: 2, sortIndex: 1),
        ]
        #expect(SortIndexing.nextIndex(after: items) == 101)
    }

    @Test func nextIndexWorksWithNegativeValues() {
        let items = [Item(id: 0, sortIndex: -3)]
        #expect(SortIndexing.nextIndex(after: items) == -2)
    }
}
