import Foundation

enum ShieldDistribution {
    struct Result<T> {
        let shards: [[T]]
        let overflow: Int
    }

    static func sortedByEncoding<T: Encodable>(_ items: Set<T>) -> [T] {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return items
            .map { (item: $0, key: (try? encoder.encode([$0])) ?? Data()) }
            .sorted { lhs, rhs in
                lhs.key.lexicographicallyPrecedes(rhs.key)
            }
            .map(\.item)
    }

    static func chunk<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0 else { return items.isEmpty ? [] : [items] }
        return stride(from: 0, to: items.count, by: size).map {
            Array(items[$0 ..< min($0 + size, items.count)])
        }
    }

    static func distribute<T: Hashable & Encodable>(
        _ items: Set<T>,
        shardCount: Int,
        chunkSize: Int
    ) -> Result<T> {
        precondition(shardCount > 0 && chunkSize > 0, "invalid shard configuration")

        let sorted = sortedByEncoding(items)
        let capacity = shardCount * chunkSize
        let overflow = max(0, sorted.count - capacity)
        let kept = Array(sorted.prefix(capacity))

        var shards = chunk(kept, size: chunkSize)
        if shards.count < shardCount {
            shards.append(contentsOf: Array(repeating: [], count: shardCount - shards.count))
        }
        return Result(shards: shards, overflow: overflow)
    }

    static func changedIndices<T: Hashable>(old: [[T]], new: [[T]]) -> [Int] {
        precondition(old.count == new.count, "distribution length mismatch")
        return (0 ..< old.count).filter { Set(old[$0]) != Set(new[$0]) }
    }
}
