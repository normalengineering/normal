import FamilyControls
import ManagedSettings

extension ShieldSettings.ActivityCategoryPolicy<Application>? {
    var tokenSet: Set<ActivityCategoryToken> {
        guard case let .specific(tokens, _) = self else { return [] }
        return tokens
    }

    static func from(tokens: Set<ActivityCategoryToken>) -> ShieldSettings.ActivityCategoryPolicy<Application>? {
        tokens.isEmpty ? nil : .specific(tokens)
    }
}

protocol ShieldShard: AnyObject {
    var applications: Set<ApplicationToken>? { get set }
    var webDomains: Set<WebDomainToken>? { get set }
    var categoryTokens: Set<ActivityCategoryToken> { get set }
    var denyAppRemoval: Bool { get set }
}

final class ManagedSettingsShard: ShieldShard {
    private let store: ManagedSettingsStore

    init(name: String) {
        store = ManagedSettingsStore(named: .init(name))
    }

    init() {
        store = ManagedSettingsStore()
    }

    var applications: Set<ApplicationToken>? {
        get { store.shield.applications }
        set { store.shield.applications = newValue }
    }

    var webDomains: Set<WebDomainToken>? {
        get { store.shield.webDomains }
        set { store.shield.webDomains = newValue }
    }

    var categoryTokens: Set<ActivityCategoryToken> {
        get { store.shield.applicationCategories.tokenSet }
        set { store.shield.applicationCategories = .from(tokens: newValue) }
    }

    var denyAppRemoval: Bool {
        get { store.application.denyAppRemoval ?? false }
        set { store.application.denyAppRemoval = newValue }
    }
}
