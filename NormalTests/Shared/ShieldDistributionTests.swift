@testable import Normal
import Testing

struct ShieldDistributionTests {
    private let shardCount = 3
    private let chunkSize = 2

    private func dist(_ items: Set<Int>) -> ShieldDistribution.Result<Int> {
        ShieldDistribution.distribute(items, shardCount: shardCount, chunkSize: chunkSize)
    }

    @Test func emptyProducesEmptyPaddedShardsNoOverflow() {
        let r = dist([])
        let total = r.shards.reduce(0) { $0 + $1.count }
        #expect(r.shards.count == shardCount)
        #expect(total == 0)
        #expect(r.overflow == 0)
    }

    @Test func singleElementLandsInOneShard() {
        let r = dist([42])
        let flat = Array(r.shards.joined())
        #expect(flat == [42])
        #expect(r.shards.count == shardCount)
        #expect(r.overflow == 0)
    }

    @Test func fillsExactlyToChunkBoundary() {
        let r = dist([1, 2])
        #expect(r.shards[0].count == 2)
        #expect(r.shards[1].isEmpty)
        #expect(r.overflow == 0)
    }

    @Test func spillsIntoNextShard() {
        let r = dist([1, 2, 3])
        #expect(r.shards[0].count == 2)
        #expect(r.shards[1].count == 1)
        #expect(r.overflow == 0)
    }

    @Test func atCapacityNoOverflow() {
        let r = dist([1, 2, 3, 4, 5, 6])
        let counts = r.shards.map(\.count)
        let placed = Set(r.shards.joined())
        #expect(counts == [2, 2, 2])
        #expect(r.overflow == 0)
        #expect(placed == [1, 2, 3, 4, 5, 6])
    }

    @Test func beyondCapacityReportsOverflowAndDropsDeterministically() {
        let r = dist([1, 2, 3, 4, 5, 6, 7, 8])
        let placedCount = r.shards.reduce(0) { $0 + $1.count }
        #expect(r.overflow == 2)
        #expect(r.shards.count == shardCount)
        #expect(placedCount == 6)
    }

    @Test func assignmentIsDeterministicRegardlessOfInsertionOrder() {
        let a = dist([5, 1, 4, 2, 3]).shards.map(Set.init)
        let b = dist([3, 2, 4, 1, 5]).shards.map(Set.init)
        #expect(a == b)
    }

    @Test func changedIndicesEmptyWhenIdentical() {
        let a = dist([1, 2, 3]).shards
        let changed = ShieldDistribution.changedIndices(old: a, new: a)
        #expect(changed.isEmpty)
    }

    @Test func changedIndicesDetectShrink() {
        let old = dist([1, 2, 3, 4, 5, 6]).shards
        let new = dist([1, 2]).shards
        let changed = ShieldDistribution.changedIndices(old: old, new: new)
        #expect(changed.contains(1))
        #expect(changed.contains(2))
    }

    @Test func sortedByEncodingIsStable() {
        let s: Set<Int> = [9, 3, 7, 1, 5]
        let first = ShieldDistribution.sortedByEncoding(s)
        let second = ShieldDistribution.sortedByEncoding(s)
        #expect(first == second)
    }
}
