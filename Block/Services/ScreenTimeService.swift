import FamilyControls
import Foundation
import ManagedSettings
import Observation

enum AuthorizationState {
    case authorized
    case notAuthorized
}

@Observable
class ScreenTimeService {
    static let shared = ScreenTimeService()

    var authorizationState: AuthorizationState = .notAuthorized

    private let store = ManagedSettingsStore()
    private let authCenter = AuthorizationCenter.shared
    private let authorizedKey = "hasAuthorizedFamilyControls"

    private(set) var activeApplicationShields = Set<ApplicationToken>()
    private(set) var activeCategoryShields = Set<ActivityCategoryToken>()
    private(set) var activeWebDomainShields = Set<WebDomainToken>()

    init() {
        Task {
            await checkAuthorizationStatus()
        }
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
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }

    func removeShieldOnAll() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    // TO DO: Group Shield Logic

    func setShieldOnGroup(selection: FamilyActivitySelection, shouldBlock: Bool) {
        if shouldBlock {
            addToShields(selection: selection)
        } else {
            subtractFromShields(selection: selection)
        }

        applyShields()
    }

    func applyShields() {
        store.shield.applications = activeApplicationShields.isEmpty ? nil : activeApplicationShields
        store.shield.applicationCategories = activeCategoryShields.isEmpty ? nil : .specific(activeCategoryShields)
        store.shield.webDomains = activeWebDomainShields.isEmpty ? nil : activeWebDomainShields

        print("Applying Shields: \(activeApplicationShields.count) apps")
        for app in activeApplicationShields {
            print(app.hashValue)
        }
    }

    func addToShields(selection: FamilyActivitySelection) {
        activeApplicationShields.formUnion(selection.applicationTokens)
        activeCategoryShields.formUnion(selection.categoryTokens)
        activeWebDomainShields.formUnion(selection.webDomainTokens)
    }

    func subtractFromShields(selection: FamilyActivitySelection) {
        activeApplicationShields.subtract(selection.applicationTokens)
        activeCategoryShields.subtract(selection.categoryTokens)
        activeWebDomainShields.subtract(selection.webDomainTokens)
    }

    func removeAllFromShields() {
        activeApplicationShields.removeAll()
        activeCategoryShields.removeAll()
        activeWebDomainShields.removeAll()
    }
}
