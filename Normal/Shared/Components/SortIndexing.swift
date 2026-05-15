import Foundation
import SwiftUI

enum SortIndexing {
    static func reorder<T: AnyObject>(
        _ items: [T],
        from source: IndexSet,
        to destination: Int,
        sortIndex: ReferenceWritableKeyPath<T, Int>
    ) -> [T] {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() {
            item[keyPath: sortIndex] = index
        }
        return reordered
    }

    static func nextIndex<T>(after items: [T], sortIndex: KeyPath<T, Int>) -> Int {
        (items.map { $0[keyPath: sortIndex] }.max() ?? -1) + 1
    }
}
