import FamilyControls
import Foundation
import ManagedSettings

protocol ShieldStoring: AnyObject {
    var denyAppRemoval: Bool { get set }
    func replace(with selection: FamilyActivitySelection)
    func clear()
    func union(with selection: FamilyActivitySelection)
    func subtract(with selection: FamilyActivitySelection)
    func shieldedCount() -> Int
    func status(for selection: FamilyActivitySelection?) -> BlockStatus
}

final class ShardedShieldStoring: ShieldStoring {
    private let store: ShardedShieldStore

    init(store: ShardedShieldStore = ShardedShieldStore()) {
        self.store = store
        store.migrateLegacyStoreIfNeeded(
            defaults: UserDefaults(suiteName: SharedConstants.appGroupID) ?? .standard
        )
    }

    var denyAppRemoval: Bool {
        get { store.denyAppRemoval }
        set { store.denyAppRemoval = newValue }
    }

    func replace(with selection: FamilyActivitySelection) { store.replaceShields(with: selection) }
    func clear() { store.clearShields() }
    func union(with selection: FamilyActivitySelection) { store.unionShields(with: selection) }
    func subtract(with selection: FamilyActivitySelection) { store.subtractShields(with: selection) }

    func shieldedCount() -> Int {
        store.shieldedApplications.count
            + store.shieldedWebDomains.count
            + store.shieldedCategories.count
    }

    func status(for selection: FamilyActivitySelection?) -> BlockStatus {
        guard let selection else { return .none }

        let currentApps = store.shieldedApplications
        let currentWeb = store.shieldedWebDomains
        let currentCats = store.shieldedCategories

        let appsDisjoint = selection.applicationTokens.isDisjoint(with: currentApps)
        let webDisjoint = selection.webDomainTokens.isDisjoint(with: currentWeb)
        let catsDisjoint = selection.categoryTokens.isDisjoint(with: currentCats)
        if appsDisjoint && webDisjoint && catsDisjoint { return .none }

        let appsSubset = selection.applicationTokens.isSubset(of: currentApps)
        let webSubset = selection.webDomainTokens.isSubset(of: currentWeb)
        let catsSubset = selection.categoryTokens.isSubset(of: currentCats)
        if appsSubset && webSubset && catsSubset { return .all }

        return .some
    }
}

final class InMemoryShieldStore: ShieldStoring {
    private var shielded: Bool
    var denyAppRemoval: Bool

    init() {
        shielded = UITestSupport.startBlocked
        denyAppRemoval = UITestSupport.startBlocked
    }

    func replace(with _: FamilyActivitySelection) { shielded = true }
    func clear() { shielded = false }
    func union(with _: FamilyActivitySelection) { shielded = true }
    func subtract(with _: FamilyActivitySelection) { shielded = false }
    func shieldedCount() -> Int { shielded ? 1 : 0 }
    func status(for _: FamilyActivitySelection?) -> BlockStatus { shielded ? .all : .none }
}
