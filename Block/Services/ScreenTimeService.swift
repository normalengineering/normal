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
}

@Observable
class ScreenTimeService {
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

    var isStrictModeEnabled: Bool {
        _ = lastUpdate
        return store.application.denyAppRemoval ?? false
    }

    private func notifyUpdate() {
        lastUpdate = .now
    }

    func checkAuthorizationStatus() async {
        let status = authCenter.authorizationStatus

        if status == .approved {
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

    func applyShieldOnAll(selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens
        notifyUpdate()
    }

    func removeShieldOnAll() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.application.denyAppRemoval = false
        notifyUpdate()
    }

    func enableStrictMode() {
        store.application.denyAppRemoval = true
        notifyUpdate()
    }

    func disableStrictMode() {
        store.application.denyAppRemoval = false
        notifyUpdate()
    }

    func addToShields(selection: FamilyActivitySelection) {
        var currentApplications = store.shield.applications ?? Set<ApplicationToken>()
        currentApplications.formUnion(selection.applicationTokens)
        store.shield.applications = currentApplications
        notifyUpdate()

        var currentWebDomains = store.shield.webDomains ?? Set<WebDomainToken>()
        currentWebDomains.formUnion(selection.webDomainTokens)
        store.shield.webDomains = currentWebDomains
    }

    func removeFromShields(selection: FamilyActivitySelection) {
        var currentApplications = store.shield.applications ?? Set<ApplicationToken>()
        currentApplications.subtract(selection.applicationTokens)
        store.shield.applications = currentApplications

        var currentWebDomains = store.shield.webDomains ?? Set<WebDomainToken>()
        currentWebDomains.subtract(selection.webDomainTokens)
        store.shield.webDomains = currentWebDomains
        notifyUpdate()
    }

    func activeShieldCount() -> Int {
        let applicationCount = store.shield.applications?.count ?? 0
        let webDomainCount = store.shield.webDomains?.count ?? 0

        return applicationCount + webDomainCount
    }

    func blockStatus(selection: FamilyActivitySelection?) -> BlockStatus {
        _ = lastUpdate
        guard let selection = selection else { return .none }
        let currentApplications = store.shield.applications ?? Set<ApplicationToken>()
        let currentWebDomains = store.shield.webDomains ?? Set<WebDomainToken>()

        if selection.applicationTokens.isDisjoint(with: currentApplications) && selection.webDomainTokens.isDisjoint(with: currentWebDomains) {
            return .none
        }

        if selection.applicationTokens.isSubset(of: currentApplications) && selection.webDomainTokens.isSubset(of: currentWebDomains) {
            return .all
        }

        return .some
    }
}
