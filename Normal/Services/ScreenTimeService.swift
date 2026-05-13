import FamilyControls
import Foundation
import ManagedSettings
import Observation

enum AuthorizationState {
    case authorized
    case notAuthorized
}

enum BlockStatus {
    case all
    case some
    case none

    var shortLabel: String {
        switch self {
        case .all: "Blocked"
        case .some: "Partial"
        case .none: "Unblocked"
        }
    }
}

@MainActor
@Observable
class ScreenTimeService: ScreenTimeProviding {
    static let shared = ScreenTimeService()

    var authorizationState: AuthorizationState = .notAuthorized

    private let store = ManagedSettingsStore()
    private let authCenter = AuthorizationCenter.shared
    private let authorizedKey = "hasAuthorizedFamilyControls"

    var lastUpdate: Date = .now

    init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    var isAppDeleteDisabled: Bool {
        _ = lastUpdate
        return store.application.denyAppRemoval ?? false
    }

    func notifyUpdate() {
        lastUpdate = .now
    }

    func checkAuthorizationStatus() async {
        if authCenter.authorizationStatus == .approved {
            authorizationState = .authorized
        } else if UserDefaults.standard.bool(forKey: authorizedKey) {
            await requestAuthorization()
        } else {
            authorizationState = .notAuthorized
        }
    }

    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            authorizationState = .authorized
            UserDefaults.standard.set(true, forKey: authorizedKey)
        } catch {
            print("Failed to authorize: \(error.localizedDescription)")
        }
    }

    func enablePreventAppDelete() {
        store.application.denyAppRemoval = true
        notifyUpdate()
    }

    func disablePreventAppDelete() {
        store.application.denyAppRemoval = false
        notifyUpdate()
    }

    func applyShieldOnAll(selection: FamilyActivitySelection, preventAppDelete: Bool) {
        store.shield.applications = selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        if preventAppDelete {
            store.application.denyAppRemoval = true
        }
        notifyUpdate()
    }

    func removeShieldOnAll(allowAppDelete: Bool) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        if allowAppDelete {
            store.application.denyAppRemoval = false
        }
        notifyUpdate()
    }

    func addToShields(selection: FamilyActivitySelection) {
        var currentApplications = store.shield.applications ?? Set<ApplicationToken>()
        currentApplications.formUnion(selection.applicationTokens)
        store.shield.applications = currentApplications

        var currentWebDomains = store.shield.webDomains ?? Set<WebDomainToken>()
        currentWebDomains.formUnion(selection.webDomainTokens)
        store.shield.webDomains = currentWebDomains

        var currentCategories = extractCategoryTokens(from: store.shield.applicationCategories)
        currentCategories.formUnion(selection.categoryTokens)
        store.shield.applicationCategories = currentCategories.isEmpty ? nil : .specific(currentCategories)

        notifyUpdate()
    }

    func removeFromShields(selection: FamilyActivitySelection) {
        var currentApplications = store.shield.applications ?? Set<ApplicationToken>()
        currentApplications.subtract(selection.applicationTokens)
        store.shield.applications = currentApplications

        var currentWebDomains = store.shield.webDomains ?? Set<WebDomainToken>()
        currentWebDomains.subtract(selection.webDomainTokens)
        store.shield.webDomains = currentWebDomains

        var currentCategories = extractCategoryTokens(from: store.shield.applicationCategories)
        currentCategories.subtract(selection.categoryTokens)
        store.shield.applicationCategories = currentCategories.isEmpty ? nil : .specific(currentCategories)

        notifyUpdate()
    }

    func activeShieldCount() -> Int {
        _ = lastUpdate
        let applicationCount = store.shield.applications?.count ?? 0
        let webDomainCount = store.shield.webDomains?.count ?? 0
        let categoryCount = extractCategoryTokens(from: store.shield.applicationCategories).count

        return applicationCount + webDomainCount + categoryCount
    }

    func blockStatus(selection: FamilyActivitySelection?) -> BlockStatus {
        _ = lastUpdate
        guard let selection = selection else { return .none }
        let currentApplications = store.shield.applications ?? Set<ApplicationToken>()
        let currentWebDomains = store.shield.webDomains ?? Set<WebDomainToken>()
        let currentCategories = extractCategoryTokens(from: store.shield.applicationCategories)

        let appsDisjoint = selection.applicationTokens.isDisjoint(with: currentApplications)
        let webDisjoint = selection.webDomainTokens.isDisjoint(with: currentWebDomains)
        let catsDisjoint = selection.categoryTokens.isDisjoint(with: currentCategories)

        if appsDisjoint && webDisjoint && catsDisjoint {
            return .none
        }

        let appsSubset = selection.applicationTokens.isSubset(of: currentApplications)
        let webSubset = selection.webDomainTokens.isSubset(of: currentWebDomains)
        let catsSubset = selection.categoryTokens.isSubset(of: currentCategories)

        if appsSubset && webSubset && catsSubset {
            return .all
        }

        return .some
    }

    private func extractCategoryTokens(
        from policy: ShieldSettings.ActivityCategoryPolicy<Application>?
    ) -> Set<ActivityCategoryToken> {
        guard case let .specific(tokens, _) = policy else { return [] }
        return tokens
    }
}
