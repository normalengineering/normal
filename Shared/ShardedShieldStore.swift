import FamilyControls
import Foundation
import ManagedSettings
import OSLog

final class ShardedShieldStore {
    static let chunkSize = 50
    static let shardCount = 40

    private let shards: [ShieldShard]
    private let truth: ShieldTruthStore
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "Shield")

    init(
        shards: [ShieldShard]? = nil,
        truth: ShieldTruthStore = ShieldTruthStore()
    ) {
        self.shards = shards ?? (0 ..< Self.shardCount).map {
            ManagedSettingsShard(name: "\(SharedConstants.shieldShardPrefix)\($0)")
        }
        self.truth = truth
    }

    var shieldedApplications: Set<ApplicationToken> {
        shards.reduce(into: Set()) { $0.formUnion($1.applications ?? []) }
    }

    var shieldedWebDomains: Set<WebDomainToken> {
        shards.reduce(into: Set()) { $0.formUnion($1.webDomains ?? []) }
    }

    var shieldedCategories: Set<ActivityCategoryToken> {
        shards.reduce(into: Set()) { $0.formUnion($1.categoryTokens) }
    }

    var denyAppRemoval: Bool {
        get { shards.contains { $0.denyAppRemoval } }
        set {
            if newValue == false {
                for shard in shards where shard.denyAppRemoval {
                    shard.denyAppRemoval = false
                }
            }
            apply { $0.denyAppRemoval = newValue }
        }
    }

    func replaceShields(with selection: FamilyActivitySelection) {
        apply {
            $0.applications = selection.applicationTokens
            $0.webDomains = selection.webDomainTokens
            $0.categories = selection.categoryTokens
        }
    }

    func unionShields(with selection: FamilyActivitySelection) {
        apply {
            $0.applications.formUnion(selection.applicationTokens)
            $0.webDomains.formUnion(selection.webDomainTokens)
            $0.categories.formUnion(selection.categoryTokens)
        }
    }

    func subtractShields(with selection: FamilyActivitySelection) {
        apply {
            $0.applications.subtract(selection.applicationTokens)
            $0.webDomains.subtract(selection.webDomainTokens)
            $0.categories.subtract(selection.categoryTokens)
        }
    }

    func clearShields() {
        forceClearAllShards()
        apply {
            $0.applications = []
            $0.webDomains = []
            $0.categories = []
        }
    }

    private func forceClearAllShards() {
        for shard in shards {
            if shard.applications != nil { shard.applications = nil }
            if shard.webDomains != nil { shard.webDomains = nil }
            if !shard.categoryTokens.isEmpty { shard.categoryTokens = [] }
        }
    }

    private func apply(_ body: (inout DesiredShield) -> Void) {
        truth.mutate(body, reconcile: { _, new in self.materialize(new) })
    }

    private func materialize(_ desired: DesiredShield) {
        let appDist = distribute(desired.applications, label: "applications")
        let webDist = distribute(desired.webDomains, label: "web domains")
        let catDist = distribute(desired.categories, label: "categories")

        for index in 0 ..< Self.shardCount {
            let shard = shards[index]

            let apps = nonEmpty(appDist[index])
            if shard.applications != apps { shard.applications = apps }

            let web = nonEmpty(webDist[index])
            if shard.webDomains != web { shard.webDomains = web }

            let cats = Set(catDist[index])
            if shard.categoryTokens != cats { shard.categoryTokens = cats }

            let deny = index == 0 ? desired.denyAppRemoval : false
            if shard.denyAppRemoval != deny { shard.denyAppRemoval = deny }
        }
    }

    private func distribute<T: Hashable & Encodable>(_ items: Set<T>, label: String) -> [[T]] {
        let dist = ShieldDistribution.distribute(items, shardCount: Self.shardCount, chunkSize: Self.chunkSize)
        if dist.overflow > 0 {
            logger.error(
                "Shield \(label, privacy: .public) exceeds capacity by \(dist.overflow, privacy: .public); excess not enforced."
            )
        }
        return dist.shards
    }

    private func nonEmpty<T>(_ array: [T]) -> Set<T>? where T: Hashable {
        array.isEmpty ? nil : Set(array)
    }

    func migrateLegacyStoreIfNeeded(defaults: UserDefaults) {
        migrateLegacyStoreIfNeeded(defaults: defaults, legacy: ManagedSettingsShard())
    }

    func migrateLegacyStoreIfNeeded(defaults: UserDefaults, legacy: ShieldShard) {
        guard !defaults.bool(forKey: SharedConstants.DefaultsKey.legacyShieldMigrated) else {
            return
        }

        let apps = legacy.applications ?? []
        let web = legacy.webDomains ?? []
        let cats = legacy.categoryTokens
        let denyRemoval = legacy.denyAppRemoval

        apply {
            $0.applications.formUnion(apps)
            $0.webDomains.formUnion(web)
            $0.categories.formUnion(cats)
            if denyRemoval { $0.denyAppRemoval = true }
        }

        legacy.applications = nil
        legacy.webDomains = nil
        legacy.categoryTokens = []
        legacy.denyAppRemoval = false

        defaults.set(true, forKey: SharedConstants.DefaultsKey.legacyShieldMigrated)
    }
}
