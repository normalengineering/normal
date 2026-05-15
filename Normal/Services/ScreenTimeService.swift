import FamilyControls
import Foundation
import ManagedSettings
import Observation
import OSLog

@MainActor
@Observable
final class ScreenTimeService: ScreenTimeProviding {
    var authorizationState: AuthorizationState = .notAuthorized
    var lastUpdate: Date = .now

    private let store = ManagedSettingsStore()
    private let authCenter = AuthorizationCenter.shared
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "ScreenTime")

    private static let authorizedKey = "hasAuthorizedFamilyControls"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Task { await checkAuthorizationStatus() }
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
        } else if defaults.bool(forKey: Self.authorizedKey) {
            await requestAuthorization()
        } else {
            authorizationState = .notAuthorized
        }
    }

    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            authorizationState = .authorized
            defaults.set(true, forKey: Self.authorizedKey)
        } catch {
            logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func ensureAuthorized() async -> Bool {
        if authorizationState == .authorized { return true }
        await requestAuthorization()
        return authorizationState == .authorized
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
        store.replaceShields(with: selection)
        if preventAppDelete {
            store.application.denyAppRemoval = true
        }
        notifyUpdate()
    }

    func removeShieldOnAll(allowAppDelete: Bool) {
        store.clearShields()
        if allowAppDelete {
            store.application.denyAppRemoval = false
        }
        notifyUpdate()
    }

    func addToShields(selection: FamilyActivitySelection) {
        store.unionShields(with: selection)
        notifyUpdate()
    }

    func removeFromShields(selection: FamilyActivitySelection) {
        store.subtractShields(with: selection)
        notifyUpdate()
    }

    func activeShieldCount() -> Int {
        _ = lastUpdate
        return (store.shield.applications?.count ?? 0)
            + (store.shield.webDomains?.count ?? 0)
            + store.shield.applicationCategories.tokenSet.count
    }

    func blockStatus(selection: FamilyActivitySelection?) -> BlockStatus {
        _ = lastUpdate
        guard let selection else { return .none }

        let currentApps = store.shield.applications ?? []
        let currentWeb = store.shield.webDomains ?? []
        let currentCats = store.shield.applicationCategories.tokenSet

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
