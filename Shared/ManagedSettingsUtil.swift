import FamilyControls
import ManagedSettings

extension ShieldSettings.ActivityCategoryPolicy<Application>? {
    var tokenSet: Set<ActivityCategoryToken> {
        guard case .specific(let tokens, _) = self else { return [] }
        return tokens
    }

    static func from(tokens: Set<ActivityCategoryToken>) -> ShieldSettings.ActivityCategoryPolicy<Application>? {
        tokens.isEmpty ? nil : .specific(tokens)
    }
}

extension ManagedSettingsStore {
    func replaceShields(with selection: FamilyActivitySelection) {
        shield.applications = selection.applicationTokens
        shield.webDomains = selection.webDomainTokens
        shield.applicationCategories = .from(tokens: selection.categoryTokens)
    }
}
