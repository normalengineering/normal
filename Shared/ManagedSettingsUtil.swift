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

extension ManagedSettingsStore {
    func unionShields(with selection: FamilyActivitySelection) {
        var apps = shield.applications ?? Set<ApplicationToken>()
        apps.formUnion(selection.applicationTokens)
        shield.applications = apps

        var web = shield.webDomains ?? Set<WebDomainToken>()
        web.formUnion(selection.webDomainTokens)
        shield.webDomains = web

        var cats = shield.applicationCategories.tokenSet
        cats.formUnion(selection.categoryTokens)
        shield.applicationCategories = .from(tokens: cats)
    }

    func subtractShields(with selection: FamilyActivitySelection) {
        var apps = shield.applications ?? Set<ApplicationToken>()
        apps.subtract(selection.applicationTokens)
        shield.applications = apps

        var web = shield.webDomains ?? Set<WebDomainToken>()
        web.subtract(selection.webDomainTokens)
        shield.webDomains = web

        var cats = shield.applicationCategories.tokenSet
        cats.subtract(selection.categoryTokens)
        shield.applicationCategories = .from(tokens: cats)
    }

    func replaceShields(with selection: FamilyActivitySelection) {
        shield.applications = selection.applicationTokens
        shield.webDomains = selection.webDomainTokens
        shield.applicationCategories = .from(tokens: selection.categoryTokens)
    }

    func clearShields() {
        shield.applications = nil
        shield.webDomains = nil
        shield.applicationCategories = nil
    }
}
