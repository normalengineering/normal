import Foundation
@testable import Normal
import Testing

struct ShieldTruthStoreTests {
    private func tempStore() -> (ShieldTruthStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shield-truth-\(UUID().uuidString).plist")
        return (ShieldTruthStore(fileURL: url), url)
    }

    @Test func snapshotOnMissingFileIsEmpty() {
        let (store, _) = tempStore()
        #expect(store.snapshot() == .empty)
    }

    @Test func mutatePersistsAndReconcileSeesOldAndNew() {
        let (store, url) = tempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        var observedOld: DesiredShield?
        var observedNew: DesiredShield?
        store.mutate({ $0.denyAppRemoval = true }, reconcile: { old, new in
            observedOld = old
            observedNew = new
        })

        #expect(observedOld == .empty)
        #expect(observedNew?.denyAppRemoval == true)
        #expect(store.snapshot().denyAppRemoval == true)
    }

    @Test func reconcileRunsEvenWhenStateUnchanged() {
        let (store, url) = tempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        var calls = 0
        store.mutate({ _ in }, reconcile: { _, _ in calls += 1 })
        #expect(calls == 1)
    }

    @Test func mutationsArePersistedAcrossInstances() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shield-truth-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }

        ShieldTruthStore(fileURL: url).mutate({ $0.denyAppRemoval = true }, reconcile: { _, _ in })
        #expect(ShieldTruthStore(fileURL: url).snapshot().denyAppRemoval == true)
    }

    @Test func concurrentMutationsAreSerializedWithoutCorruption() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shield-truth-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }

        let lock = NSLock()
        var reconcileCalls = 0
        let iterations = 50

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            let store = ShieldTruthStore(fileURL: url)
            store.mutate({ $0.denyAppRemoval = true }, reconcile: { _, _ in
                lock.lock(); reconcileCalls += 1; lock.unlock()
            })
        }

        #expect(reconcileCalls == iterations)
        #expect(ShieldTruthStore(fileURL: url).snapshot().denyAppRemoval == true)
    }
}
