import FamilyControls
import Foundation
@testable import Normal
import Testing

struct ShardedShieldStoreTests {
    private func makeStore() -> (ShardedShieldStore, [InMemoryShieldShard], URL) {
        let shards = (0 ..< ShardedShieldStore.shardCount).map { _ in InMemoryShieldShard() }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sharded-\(UUID().uuidString).plist")
        let store = ShardedShieldStore(shards: shards, truth: ShieldTruthStore(fileURL: url))
        return (store, shards, url)
    }

    private func volatileDefaults() -> (UserDefaults, String) {
        let name = "test-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func denyAppRemovalSetterPropagatesToTruthAndShardZero() {
        let (store, shards, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.denyAppRemoval = true
        #expect(store.denyAppRemoval == true)
        #expect(shards[0].denyAppRemoval == true)

        store.denyAppRemoval = false
        #expect(store.denyAppRemoval == false)
        #expect(shards[0].denyAppRemoval == false)
    }

    @Test func migrationCarriesDenyAppRemovalClearsLegacyAndSetsFlag() {
        let (store, shards, url) = makeStore()
        let (defaults, name) = volatileDefaults()
        defer {
            try? FileManager.default.removeItem(at: url)
            defaults.removePersistentDomain(forName: name)
        }

        let legacy = InMemoryShieldShard()
        legacy.denyAppRemoval = true

        store.migrateLegacyStoreIfNeeded(defaults: defaults, legacy: legacy)

        #expect(defaults.bool(forKey: SharedConstants.DefaultsKey.legacyShieldMigrated))
        #expect(store.denyAppRemoval == true)
        #expect(shards[0].denyAppRemoval == true)
        #expect(legacy.denyAppRemoval == false)
    }

    @Test func migrationIsIdempotent() {
        let (store, _, url) = makeStore()
        let (defaults, name) = volatileDefaults()
        defer {
            try? FileManager.default.removeItem(at: url)
            defaults.removePersistentDomain(forName: name)
        }

        let legacy = InMemoryShieldShard()
        legacy.denyAppRemoval = true
        store.migrateLegacyStoreIfNeeded(defaults: defaults, legacy: legacy)

        legacy.denyAppRemoval = true
        store.migrateLegacyStoreIfNeeded(defaults: defaults, legacy: legacy)
        #expect(legacy.denyAppRemoval == true)
    }

    @Test func migrationSkippedWhenFlagAlreadySet() {
        let (store, _, url) = makeStore()
        let (defaults, name) = volatileDefaults()
        defer {
            try? FileManager.default.removeItem(at: url)
            defaults.removePersistentDomain(forName: name)
        }
        defaults.set(true, forKey: SharedConstants.DefaultsKey.legacyShieldMigrated)

        let legacy = InMemoryShieldShard()
        legacy.denyAppRemoval = true
        store.migrateLegacyStoreIfNeeded(defaults: defaults, legacy: legacy)

        #expect(legacy.denyAppRemoval == true)
        #expect(store.denyAppRemoval == false)
    }

    @Test func emptyMutationsAreSafeNoOps() {
        let (store, _, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.replaceShields(with: .init())
        store.unionShields(with: .init())
        store.subtractShields(with: .init())
        store.clearShields()

        #expect(store.shieldedApplications.isEmpty)
        #expect(store.shieldedWebDomains.isEmpty)
        #expect(store.shieldedCategories.isEmpty)
    }

    @Test func denyAppRemovalFalseClearsStrayShardWhenTruthIsEmpty() {
        let (store, shards, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        shards[0].denyAppRemoval = true
        shards[7].denyAppRemoval = true
        #expect(store.denyAppRemoval == true)

        store.denyAppRemoval = false

        #expect(shards.allSatisfy { $0.denyAppRemoval == false })
    }

    @Test func reconcileForcesStrayShardBackInSyncOnAnyMutation() {
        let (store, shards, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        shards[5].denyAppRemoval = true

        store.clearShields() 

        #expect(shards[5].denyAppRemoval == false)
        #expect(shards.allSatisfy { $0.denyAppRemoval == false })
    }

    @Test func clearShieldsForcesPhysicalEvenWhenTruthUnchanged() {
        let (store, shards, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        shards[0].denyAppRemoval = true
        store.clearShields()
        store.denyAppRemoval = false

        #expect(store.shieldedApplications.isEmpty)
        #expect(shards.allSatisfy { $0.denyAppRemoval == false })
    }
}
