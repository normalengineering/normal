import FamilyControls
import ManagedSettings

protocol ShieldStoring: ShieldApplying {
    func clearAllSettings()
}

extension ShieldStoring {
    var denyAppRemoval: Bool {
        currentShields().denyAppRemoval ?? false
    }

    func shieldedCount() -> Int {
        currentShields().shieldedCount
    }

    func status(for selection: FamilyActivitySelection?, customDomains: [String]?) -> BlockStatus {
        currentShields().status(for: selection, customDomains: customDomains)
    }

    func isShielded(_ token: SelectedTokenKind) -> Bool {
        currentShields().isShielded(token)
    }

    func isCustomDomainShielded(_ domain: String) -> Bool {
        currentShields().isCustomDomainShielded(domain)
    }

    func hasActiveCustomDomainFilter() -> Bool {
        !currentShields().customDomains.isEmpty
    }
}

extension ShieldPlan {
    var shieldedCount: Int {
        applications.count + webDomains.count + categories.count + customDomains.count
    }

    func status(for selection: FamilyActivitySelection?, customDomains domains: [String]?) -> BlockStatus {
        guard let selection else { return .none }
        let targetDomains = Set((domains ?? []).compactMap(DomainNormalizer.normalize))

        let disjoint =
            selection.applicationTokens.isDisjoint(with: applications)
            && selection.webDomainTokens.isDisjoint(with: webDomains)
            && selection.categoryTokens.isDisjoint(with: categories)
            && targetDomains.isDisjoint(with: customDomains)
        if disjoint {
            return .none
        }

        let subset =
            selection.applicationTokens.isSubset(of: applications)
            && selection.webDomainTokens.isSubset(of: webDomains)
            && selection.categoryTokens.isSubset(of: categories)
            && targetDomains.isSubset(of: customDomains)
        return subset ? .all : .some
    }

    func isShielded(_ token: SelectedTokenKind) -> Bool {
        switch token {
        case .application(let t): applications.contains(t)
        case .webDomain(let t): webDomains.contains(t)
        case .category(let t): categories.contains(t)
        }
    }

    func isCustomDomainShielded(_ domain: String) -> Bool {
        guard let normalized = DomainNormalizer.normalize(domain) else { return false }
        return customDomains.contains(normalized)
    }
}

final class ManagedSettingsShieldStore: ShieldStoring {
    private let store = ManagedSettingsStore()

    func currentShields() -> ShieldPlan {
        store.currentShields()
    }

    func apply(_ plan: ShieldPlan) {
        store.apply(plan)
    }

    func clearAllSettings() {
        store.clearAllSettings()
    }
}

final class InMemoryShieldStore: ShieldStoring {
    private var plan = ShieldPlan()

    init(startBlocked: Bool = UITestSupport.startBlocked) {
        guard startBlocked else { return }
        plan.formUnion(UITestSupport.mainSelection, customDomains: UITestSupport.mainCustomDomains)
        plan.denyAppRemoval = true
    }

    func currentShields() -> ShieldPlan {
        plan
    }

    func apply(_ plan: ShieldPlan) {
        let denyAppRemoval = plan.denyAppRemoval ?? self.plan.denyAppRemoval
        self.plan = plan
        self.plan.denyAppRemoval = denyAppRemoval
    }

    func clearAllSettings() {
        plan = ShieldPlan()
    }
}
