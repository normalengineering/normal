import FamilyControls
import ManagedSettings

protocol ShieldStoring: AnyObject {
    var denyAppRemoval: Bool { get set }
    func replace(with selection: FamilyActivitySelection, customDomains: [String])
    func clear()
    func union(with selection: FamilyActivitySelection, customDomains: [String])
    func subtract(with selection: FamilyActivitySelection, customDomains: [String])
    func clearCustomDomainFilter()
    func shieldedCount() -> Int
    func status(for selection: FamilyActivitySelection?, customDomains: [String]?) -> BlockStatus
    func isShielded(_ token: SelectedTokenKind) -> Bool
}

final class ManagedSettingsShieldStore: ShieldStoring {
    private let store = ManagedSettingsStore()

    var denyAppRemoval: Bool {
        get { store.application.denyAppRemoval ?? false }
        set { store.application.denyAppRemoval = newValue }
    }

    func replace(with selection: FamilyActivitySelection, customDomains: [String]) {
        store.replaceShields(with: selection)
        store.replaceFilterDomains(customDomains)
    }

    func clear() {
        store.clearShields()
        store.clearFilterDomains()
    }

    func union(with selection: FamilyActivitySelection, customDomains: [String]) {
        store.unionShields(with: selection)
        store.unionFilterDomains(customDomains)
    }

    func subtract(with selection: FamilyActivitySelection, customDomains: [String]) {
        store.subtractShields(with: selection)
        store.subtractFilterDomains(customDomains)
    }

    func clearCustomDomainFilter() {
        store.clearFilterDomains()
    }

    func shieldedCount() -> Int {
        (store.shield.applications?.count ?? 0)
            + (store.shield.webDomains?.count ?? 0)
            + store.shield.applicationCategories.tokenSet.count
            + store.filterDomains().count
    }

    func status(for selection: FamilyActivitySelection?, customDomains: [String]?) -> BlockStatus {
        guard let selection else { return .none }

        let currentApps = store.shield.applications ?? []
        let currentWeb = store.shield.webDomains ?? []
        let currentCats = store.shield.applicationCategories.tokenSet
        let currentDomains = store.filterDomains()
        let targetDomains = Set(
            (customDomains ?? []).compactMap(DomainNormalizer.normalize).map { WebDomain(domain: $0) }
        )

        let appsDisjoint = selection.applicationTokens.isDisjoint(with: currentApps)
        let webDisjoint = selection.webDomainTokens.isDisjoint(with: currentWeb)
        let catsDisjoint = selection.categoryTokens.isDisjoint(with: currentCats)
        let domainsDisjoint = targetDomains.isDisjoint(with: currentDomains)
        if appsDisjoint && webDisjoint && catsDisjoint && domainsDisjoint { return .none }

        let appsSubset = selection.applicationTokens.isSubset(of: currentApps)
        let webSubset = selection.webDomainTokens.isSubset(of: currentWeb)
        let catsSubset = selection.categoryTokens.isSubset(of: currentCats)
        let domainsSubset = targetDomains.isSubset(of: currentDomains)
        if appsSubset && webSubset && catsSubset && domainsSubset { return .all }

        return .some
    }

    func isShielded(_ token: SelectedTokenKind) -> Bool {
        switch token {
        case let .application(t): (store.shield.applications ?? []).contains(t)
        case let .webDomain(t): (store.shield.webDomains ?? []).contains(t)
        case let .category(t): store.shield.applicationCategories.tokenSet.contains(t)
        }
    }
}

final class InMemoryShieldStore: ShieldStoring {
    private var shielded: Bool
    var denyAppRemoval: Bool

    init() {
        shielded = UITestSupport.startBlocked
        denyAppRemoval = UITestSupport.startBlocked
    }

    func replace(with _: FamilyActivitySelection, customDomains _: [String]) { shielded = true }
    func clear() { shielded = false }
    func union(with _: FamilyActivitySelection, customDomains _: [String]) { shielded = true }
    func subtract(with _: FamilyActivitySelection, customDomains _: [String]) { shielded = false }
    func clearCustomDomainFilter() {}
    func shieldedCount() -> Int { shielded ? 1 : 0 }
    func status(for _: FamilyActivitySelection?, customDomains _: [String]?) -> BlockStatus { shielded ? .all : .none }
    func isShielded(_: SelectedTokenKind) -> Bool { shielded }
}
